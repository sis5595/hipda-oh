import { FourD4ySmiley, FourD4ySmileyInsertion, getFourD4ySmilies, insertFourD4ySmiley }
  from '../../domain/composer/FourD4ySmilies';

@Component
export struct ForumSmileyButton {
  @Link text: string;
  @Link selectionStart: number;
  @Link selectionEnd: number;
  controller: TextAreaController = new TextAreaController();
  @State private visible: boolean = false;
  @State private group: number = 0;
  @State private items: FourD4ySmiley[] = getFourD4ySmilies(0);
  @State private selected: FourD4ySmiley[] = [];
  private caretTimer: number = -1;
  private alive: boolean = false;

  aboutToAppear(): void { this.alive = true; }

  aboutToDisappear(): void {
    this.alive = false;
    if (this.caretTimer >= 0) { clearTimeout(this.caretTimer); }
  }

  private insert(item: FourD4ySmiley): void {
    const result: FourD4ySmileyInsertion = insertFourD4ySmiley(this.text,
      this.selectionStart, this.selectionEnd, item.code);
    this.text = result.text;
    this.selectionStart = result.caret;
    this.selectionEnd = result.caret;
    this.selected = this.selected.concat([item]).slice(-8);
  }

  @Builder
  private panel() {
    Column({ space: 8 }) {
      Row() {
        ForEach(['默认表情', '酷猴', '呆呆男'], (label: string, index: number) => {
          Button(label).fontSize(14).layoutWeight(1).height(36)
            .backgroundColor(this.group === index ? $r('app.color.fill_selected') : Color.Transparent)
            .fontColor(this.group === index ? $r('app.color.brand') : $r('app.color.text_secondary'))
            .onClick(() => { this.group = index; this.items = getFourD4ySmilies(index); })
        })
        Button('完成').fontSize(14).height(36)
          .onClick(() => { this.visible = false; })
      }.width('100%')
      Grid() {
        ForEach(this.items, (item: FourD4ySmiley) => {
          GridItem() {
            ForumSmileyTile({ item: item, onPick: () => { this.insert(item); } })
          }.height(48)
        }, (item: FourD4ySmiley) => item.code)
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(4).layoutWeight(1).width('100%')
      Row({ space: 6 }) {
        Text('已插入').fontSize(12).fontColor($r('app.color.text_secondary'))
        ForEach(this.selected, (item: FourD4ySmiley) => {
          Image(item.imageUrl).width(24).height(24).objectFit(ImageFit.Contain)
        })
      }.height(28).width('100%')
    }.padding(12).width('100%').height('100%').backgroundColor($r('app.color.surface'))
  }

  build() {
    Button('表情').fontSize(13).height(36).padding({ left: 8, right: 8 })
      .backgroundColor(Color.Transparent).fontColor($r('app.color.brand'))
      .onClick(() => {
        this.controller.stopEditing();
        this.selected = [];
        this.visible = true;
      })
      .bindSheet($$this.visible, this.panel(), {
        height: 320,
        showClose: false,
        onDisappear: () => {
          if (!this.alive) { return; }
          if (this.caretTimer >= 0) { clearTimeout(this.caretTimer); }
          this.caretTimer = setTimeout(() => {
            if (this.alive && this.selectionEnd >= 0) {
              this.controller.caretPosition(this.selectionEnd);
            }
            this.caretTimer = -1;
          }, 50);
        }
      })
  }
}

@Component
struct ForumSmileyTile {
  item: FourD4ySmiley = { code: '', label: '', imageUrl: '' };
  onPick: () => void = () => {};
  @State private ready: boolean = false;

  build() {
    Stack() {
      if (!this.ready) {
        Text(this.item.label).fontSize(11).fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center).maxLines(2)
      }
      Image(this.item.imageUrl).width(36).height(36).objectFit(ImageFit.Contain)
        .opacity(this.ready ? 1 : 0)
        .onComplete(() => { this.ready = true; })
        .onError(() => { this.ready = false; })
    }.width('100%').height(48).accessibilityText(this.item.label)
      .onClick(() => { this.onPick(); })
  }
}
