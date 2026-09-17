/** Account-scoped reader mirrors must reset after a verified identity change. */
export class FourD4yAccountState {
  private sessionGeneration: number = 0;

  markSessionChanged(): void {
    this.sessionGeneration += 1;
  }

  getSessionGeneration(): number {
    return this.sessionGeneration;
  }
}
