pub const RecurramError = error{
    UnexpectedEof,
    InvalidKind,
    InvalidTag,
    InvalidData,
    Utf8Error,
    UnknownReference,
    StatelessRetryRequired,
    UnsupportedKind,
};

pub const Result = RecurramError;
