import { webview } from '@kit.ArkWeb';
import { WebRouteState } from './WebRouteState';

@Component
export struct WebContentPage {
  @Consume('webRoute') webRoute: WebRouteState;
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Web({ src: this.webRoute.url, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onlineImageAccess(true)
        .width('100%')
        .height('100%')
    }
    .title(this.webRoute.title || '链接')
  }
}
