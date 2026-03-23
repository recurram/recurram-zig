pub const GoweError = error{
    UnexpectedEof,
    InvalidKind,
    InvalidTag,
    InvalidData,
    Utf8Error,
    UnknownReference,
    StatelessRetryRequired,
    UnsupportedKind,
};

pub const Result = GoweError;
