const JSZip = require("jszip");
const PDFDocument = require("pdfkit");
const prisma = require("../../lib/prisma");
const { dayjs, endOfMonth, startOfMonth } = require("../../utils/date");

async function monthlyAttendanceRows({ month, departmentId, shiftId, status }) {
  const rows = await prisma.attendance.findMany({
    where: {
      timestamp: {
        gte: startOfMonth(month),
        lte: endOfMonth(month),
      },
      status: status || undefined,
      user: {
        departmentId: departmentId || undefined,
        shiftId: shiftId || undefined,
      },
    },
    include: {
      user: {
        include: {
          department: true,
          shift: true,
        },
      },
    },
    orderBy: [{ userId: "asc" }, { timestamp: "asc" }],
  });

  return rows.map((item) => ({
    id: item.id,
    nip: item.user.nip,
    name: item.user.name,
    department: item.user.department?.name || "",
    shift: item.user.shift?.name || "",
    type: item.type,
    timestamp: item.timestamp.toISOString(),
    status: item.status,
    distanceM: Math.round(item.distanceM),
    anomaly: item.anomalyFlag ? "YA" : "TIDAK",
  }));
}

function toCsv(rows) {
  const headers = ["id", "nip", "name", "department", "shift", "type", "timestamp", "status", "distanceM", "anomaly"];
  const lines = [headers.join(",")];
  for (const row of rows) {
    lines.push(headers.map((header) => JSON.stringify(row[header] ?? "")).join(","));
  }
  return lines.join("\n");
}

async function toWorkbook(rows) {
  const headers = ["id", "nip", "name", "department", "shift", "type", "timestamp", "status", "distanceM", "anomaly"];
  const zip = new JSZip();

  zip.file("[Content_Types].xml", contentTypesXml());
  zip.folder("_rels").file(".rels", rootRelsXml());
  zip.folder("xl").file("workbook.xml", workbookXml());
  zip.folder("xl").folder("_rels").file("workbook.xml.rels", workbookRelsXml());
  zip.folder("xl").file("styles.xml", stylesXml());
  zip.folder("xl").folder("worksheets").file("sheet1.xml", worksheetXml(headers, rows));

  return zip.generateAsync({ type: "nodebuffer" });
}

function toPdf(rows, month) {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ margin: 36, size: "A4" });
    const chunks = [];
    doc.on("data", (chunk) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));

    doc.fontSize(16).text(`Laporan Absensi ${month}`, { underline: true });
    doc.moveDown();
    rows.slice(0, 200).forEach((row) => {
      doc
        .fontSize(9)
        .text(`${row.nip} | ${row.name} | ${row.timestamp} | ${row.type} | ${row.status} | ${row.anomaly}`);
    });
    if (rows.length > 200) {
      doc.moveDown().text(`Data dipotong untuk preview PDF. Total baris: ${rows.length}`);
    }
    doc.end();
  });
}

async function analytics({ month }) {
  const selectedMonth = month || dayjs().format("YYYY-MM");
  const [rows, totalEmployees] = await Promise.all([
    monthlyAttendanceRows({ month: selectedMonth }),
    prisma.user.count({ where: { isActive: true } }),
  ]);
  const totalAttendances = rows.length;
  const byStatus = rows.reduce((acc, row) => {
    acc[row.status] = (acc[row.status] || 0) + 1;
    return acc;
  }, {});
  const presentRows = (byStatus.HADIR || 0) + (byStatus.TERLAMBAT || 0);
  const employeesWithAttendance = new Set(
    rows
      .filter((row) => row.status === "HADIR" || row.status === "TERLAMBAT")
      .map((row) => row.nip),
  ).size;
  const averageAttendanceRate =
    totalEmployees > 0 ? Number(((employeesWithAttendance / totalEmployees) * 100).toFixed(0)) : 0;
  const lateRanking = rows
    .filter((row) => row.status === "TERLAMBAT")
    .reduce((acc, row) => {
      acc[row.nip] = acc[row.nip] || { nip: row.nip, name: row.name, count: 0 };
      acc[row.nip].count += 1;
      return acc;
    }, {});

  return {
    month: selectedMonth,
    totalEmployees,
    totalAttendances,
    averageAttendanceRate,
    anomalies: rows.filter((row) => row.anomaly === "YA" || row.status === "REVIEW").length,
    byStatus,
    attendanceRate: totalAttendances > 0 ? Number((presentRows / totalAttendances).toFixed(2)) : 0,
    topLateEmployees: Object.values(lateRanking)
      .sort((a, b) => b.count - a.count)
      .slice(0, 10),
  };
}

module.exports = {
  analytics,
  monthlyAttendanceRows,
  toCsv,
  toPdf,
  toWorkbook,
};

function worksheetXml(headers, rows) {
  const allRows = [headers, ...rows.map((row) => headers.map((header) => row[header] ?? ""))];
  const xmlRows = allRows
    .map((row, rowIndex) => {
      const cells = row
        .map((value, columnIndex) => {
          const ref = `${columnName(columnIndex + 1)}${rowIndex + 1}`;
          return `<c r="${ref}" t="inlineStr"><is><t>${escapeXml(String(value))}</t></is></c>`;
        })
        .join("");
      return `<row r="${rowIndex + 1}">${cells}</row>`;
    })
    .join("");

  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>${xmlRows}</sheetData>
</worksheet>`;
}

function columnName(index) {
  let value = "";
  let current = index;
  while (current > 0) {
    const remainder = (current - 1) % 26;
    value = String.fromCharCode(65 + remainder) + value;
    current = Math.floor((current - 1) / 26);
  }
  return value;
}

function escapeXml(value) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function contentTypesXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>`;
}

function rootRelsXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>`;
}

function workbookXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Absensi" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>`;
}

function workbookRelsXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>`;
}

function stylesXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border/></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>`;
}
