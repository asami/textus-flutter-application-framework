# 共通 Display 操作の日本語表示 — 2026-11-06

Editing Studio App Phase 6.10 の日本語表示要件に対応する限定 Step。
CncfDisplayResourceView は実際の BuildContext の locale が ja の場合に、
編集・保存・キャンセル・再読込・破棄確認と受付・失敗の共通案内を日本語で表示する。
非日本語 locale は既存の英語を維持する。新しい公開 API や依存関係は追加していない。

利用者や producer のラベル・値、outcome・revision、action ID と presentation context、
画面・controller の寿命、保存と再読込の条件・回数は変更していない。
テスト用の locale delegate は Navigator の上で実際の locale を与える fixture であり、
本番の翻訳資源やサーバーの成功結果を代用するものではない。

新しい日本語操作シナリオと既存英語の操作回帰を合わせた 5 テストファイル・66 件、
変更した 2 ファイルの静的解析、書式・差分確認が成功した。
App 側の対応する接続・操作回帰 21 件も成功した。
独立 Step レビューの唯一の指摘は新しいテストの When／Then コメント配置であり、
振る舞いとテスト内容を変えない M0 修正を親が確認して閉じた。
実行証跡と独立レビュー原本はローカルに保持し、リポジトリには含めない。

この限定 Step は、実サーバー・実機・SDK 通信観測・P0・App Phase 6.10 全体の
受入れや、既に完了した Framework Phase の変更を意味しない。
