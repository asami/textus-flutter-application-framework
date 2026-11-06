# Media processing information presentation

`MediaProcessingInformationPage` is exported by
`textus_flutter_application_framework.dart`. Its const constructor requires a
`String title` and an ordered
`List<({String heading, String description})> sections`, with optional `key`.
Consumers supply the explanation and retain responsibility for its meaning and
provider attribution. The page displays each heading and description in order
inside a padded, scrollable safe area.

The page borrows an enclosing `ApplicationTextScaling` boundary and uses
`applicationTextAppBar` when available. It inherits ordinary Flutter text scaling
otherwise. Body text wraps, and the common title treatment can wrap and scroll;
the page does not clamp text. The route uses normal Flutter Back navigation and
does not own or dispose the borrowed Settings view.

This is passive presentation. It has no service, callback, preference, provider
discovery, network or operation dependency. Reading it grants no consent,
changes no policy, starts no recognition and authorizes no submission. It does
not inspect SDK configuration or certify actual device/network behavior.

The NICT Editing Studio App consumes the page from Home through the compact
「認識とデータの扱い」 entry. Home owns that route's navigation reservation and
releases it only for its still-live generation. Closing this information route
does not refresh the borrowed collection or submission overview. Existing Home
actions retain their own operation and refresh contracts.
