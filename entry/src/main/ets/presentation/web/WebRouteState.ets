export class WebRouteState {
  url: string = '';
  title: string = '';

  open(url: string, title: string): void {
    this.url = url;
    this.title = title;
  }
}
