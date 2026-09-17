/**
 * Value-free classification of a native 4D4Y HTTP failure.
 *
 * This deliberately holds only a numeric HTTP status or Network Kit error
 * code. It must never carry a request URL, response body, cookie, or forum
 * content: PM search failures can be shown and diagnosed without retaining
 * private-message data.
 */
export enum FourD4yNativeRequestFailureKind {
  HttpStatus = 'http-status',
  ResponseBody = 'response-body',
  Timeout = 'timeout',
  NameResolution = 'name-resolution',
  Connection = 'connection',
  RemoteAccess = 'remote-access',
  Transfer = 'transfer',
  Security = 'security',
  Redirect = 'redirect',
  NoResponse = 'no-response',
  Other = 'other'
}

export interface FourD4yNativeRequestFailure {
  kind: FourD4yNativeRequestFailureKind;
  httpStatusCode: number;
  networkErrorCode: number;
}

export function classifyFourD4yHttpFailure(responseCode: number,
  hasExpectedBody: boolean): FourD4yNativeRequestFailure {
  if (responseCode !== 200) {
    return {
      kind: FourD4yNativeRequestFailureKind.HttpStatus,
      httpStatusCode: normalizePositiveCode(responseCode),
      networkErrorCode: 0
    };
  }
  return {
    kind: hasExpectedBody ? FourD4yNativeRequestFailureKind.Other : FourD4yNativeRequestFailureKind.ResponseBody,
    httpStatusCode: hasExpectedBody ? 200 : 0,
    networkErrorCode: 0
  };
}

export function classifyFourD4yNetworkFailure(errorCode: number): FourD4yNativeRequestFailure {
  const normalizedCode: number = normalizePositiveCode(errorCode);
  let kind: FourD4yNativeRequestFailureKind = FourD4yNativeRequestFailureKind.Other;
  if (normalizedCode === 2300028) {
    kind = FourD4yNativeRequestFailureKind.Timeout;
  } else if (normalizedCode === 2300005 || normalizedCode === 2300006) {
    kind = FourD4yNativeRequestFailureKind.NameResolution;
  } else if (normalizedCode === 2300007) {
    kind = FourD4yNativeRequestFailureKind.Connection;
  } else if (normalizedCode === 2300009 || normalizedCode === 2300998) {
    kind = FourD4yNativeRequestFailureKind.RemoteAccess;
  } else if (normalizedCode === 2300047) {
    kind = FourD4yNativeRequestFailureKind.Redirect;
  } else if (normalizedCode === 2300052) {
    kind = FourD4yNativeRequestFailureKind.NoResponse;
  } else if (normalizedCode === 2300055 || normalizedCode === 2300056 || normalizedCode === 2300018) {
    kind = FourD4yNativeRequestFailureKind.Transfer;
  } else if (normalizedCode >= 2300058 && normalizedCode <= 2300061) {
    kind = FourD4yNativeRequestFailureKind.Security;
  }
  return { kind: kind, httpStatusCode: 0, networkErrorCode: normalizedCode };
}

/** A short, value-free message suitable for a PM-search failure state. */
export function describeFourD4yNativeRequestFailure(failure: FourD4yNativeRequestFailure | null): string {
  if (failure === null) {
    return '网络请求失败';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.HttpStatus) {
    if (failure.httpStatusCode === 401 || failure.httpStatusCode === 403) {
      return '论坛暂时拒绝读取会话（HTTP ' + failure.httpStatusCode + '）';
    }
    if (failure.httpStatusCode === 429) {
      return '论坛暂时限制请求（HTTP 429）';
    }
    if (failure.httpStatusCode >= 500 && failure.httpStatusCode <= 599) {
      return '论坛服务暂时不可用（HTTP ' + failure.httpStatusCode + '）';
    }
    return '论坛返回异常状态（HTTP ' + failure.httpStatusCode + '）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.ResponseBody) {
    return '论坛响应内容无法读取';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.Timeout) {
    return '网络请求超时（错误码 2300028）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.NameResolution) {
    return '无法解析论坛服务器地址（错误码 ' + failure.networkErrorCode + '）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.Connection) {
    return '无法连接论坛服务器（错误码 2300007）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.RemoteAccess) {
    return '当前网络环境拒绝访问论坛（错误码 ' + failure.networkErrorCode + '）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.Redirect) {
    return '论坛重定向次数过多（错误码 2300047）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.NoResponse) {
    return '论坛没有返回响应（错误码 2300052）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.Transfer) {
    return '网络传输中断（错误码 ' + failure.networkErrorCode + '）';
  }
  if (failure.kind === FourD4yNativeRequestFailureKind.Security) {
    return '论坛连接安全校验失败（错误码 ' + failure.networkErrorCode + '）';
  }
  return failure.networkErrorCode > 0 ?
    '网络请求失败（错误码 ' + failure.networkErrorCode + '）' : '网络请求失败';
}

function normalizePositiveCode(value: number): number {
  return Number.isInteger(value) && value > 0 ? value : 0;
}
