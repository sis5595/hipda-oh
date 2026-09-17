export enum SessionStatus {
  Unknown = 'unknown',
  SignedOut = 'signed_out',
  SigningIn = 'signing_in',
  SignedIn = 'signed_in',
  Expired = 'expired'
}

export interface SessionState {
  status: SessionStatus;
  userName?: string;
}
