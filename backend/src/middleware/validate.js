const { badRequest } = require("../utils/errors");

function validate(schema) {
  return function validateRequest(req, res, next) {
    const result = schema.safeParse({
      body: req.body,
      query: req.query,
      params: req.params,
    });

    if (!result.success) {
      return next(badRequest("Payload tidak valid", result.error.flatten()));
    }

    req.validated = result.data;
    return next();
  };
}

module.exports = validate;

