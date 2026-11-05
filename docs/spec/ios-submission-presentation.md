# iOS submission presentation contract

The common settings page borrows a `SubmissionSettingsController` bound through
`SubmissionConfigurationFacade(store: configuration)` to Core's
`IosSubmissionConfigurationStore`. Core owns persistence, processing and
credential access. The generic facade supplies safe configuration reads/writes;
it has neither interactive Drive authorization nor a manual HTTP credential
writer. Mount/build must remain inert. Only explicit settings commands load or
change definitions, selection and reference declarations, and selections apply
to newly registered intent. Owners detach/drain before independently owned stores
close. Closing a page never closes borrowed configuration or capture storage.

The TKL-only settings form requests a service connection and HTTPS service root
ending in `/`. TKL supplies destination and transfer instructions; physical Google
storage is configured on the server. This page hides Drive/account/folder setup,
reference-access editing and unavailable authorization/credential controls. Safe
legacy definitions remain stored. No default endpoint, token, account or session
is provisioned by presentation.

All built-in operator settings labels and fixed failures are Japanese. Connection
IDs, endpoints, user data, API/error identities and enum values remain literal
and unchanged. Display authorization maps `available` to `利用可能`,
`authorizationRequired` to `認証が必要`, `unavailable` to `利用不可`, and absence
to `未確認`. HTTP bearer requirement displays `必要` or `不要` without changing
the boolean. The page maps the controller's closed failure-code vocabulary to
fixed Japanese messages and uses `送信設定を読み込めませんでした。` for unavailable
or unknown failures. It never renders raw exception text or credentials. This
mapping does not change Core or controller error APIs.

The Commit control defaults to `送信待ちに登録`; busy display is
`登録しています…`. A queued result displays
`送信待ちに登録済み: <request-id>`, a scheduling warning displays
`送信待ちに登録済みです。送信処理の手配を確認してください。`, and failure displays
`送信待ちに登録できませんでした。`. Caller labels and disabled reasons retain their
existing authority. Pending Studio handoff notices also use `送信処理の手配`.
Queued, pending, uncertain and accepted remain distinct: none of these notices
asserts server receipt or OS background work. Existing callback/selection/owner
fences and explicit actions remain in force.

`SubmissionStatusPage.executionMode` defaults to
`SubmissionExecutionMode.unknown`. Only an actual bound
`SubmissionExecutionMode.foreground` renders the detail supplement:

> アプリを開いている間に送信します。閉じても送信待ちの内容は保持されます。

The App must pass Core resources' actual execution mode through its composition.
Unknown supplies no foreground/background claim. This is capability information
only; it conveys no ACK, network readiness, session, participant or owner
authority. It introduces no controller, scheduling action or wrapper layout.
Core's existing foreground processing and cancellation remain authoritative.

Host executable specifications cover a real temporary iOS configuration file
with injected FFI, generic facade and common page: inert mount, explicit reload,
TKL-only capability presentation, exact persisted endpoint/selection, no credential
read or scheduling dispatch, and a borrowed owner's accepted-read drain. Common
status specifications retain queued/ACK truth and zero scheduling on reads for
unknown and actual foreground modes. These are host behavior specifications;
they do not qualify physical iOS lifecycle or real service/participant behavior.
No token codec, server readiness API or session authority is introduced here.
