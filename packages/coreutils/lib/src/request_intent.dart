/// Request `extra` flag for requests that change server state, such as adding
/// a favorite through a GET endpoint. Infrastructure that may replay a request
/// elsewhere, like a challenge browser, must not replay these.
const stateChangingRequestKey = 'coreutils.state_changing_request';

const stateChangingRequestExtra = <String, Object?>{
  stateChangingRequestKey: true,
};

/// Omits query parameters and server content from request diagnostics.
const privateRequestDiagnosticsKey = 'coreutils.private_request_diagnostics';

/// Preserves the request's profile cookies when protection cookies are added.
const preferRequestCookiesKey = 'coreutils.prefer_request_cookies';
