# Caller-owned editable focus

VoiceTextField now accepts an optional FocusNode and forwards it to its actual
TextField. The caller owns and disposes this node. A null argument preserves
existing default behavior; the common widget does not request initial focus.

This supports the explicit App request that adding an annotation text block
both reveals its field and permits typing immediately. Domain-specific Add and
owner/route guards remain in App. No voice-session, microphone, controller value,
credential, Core contract or provider behavior is changed.

The existing common-field specification passed15 cases, including a new caller
focus/ordinary typing case and node usability after widget unmount. Exact source
and test analysis is clean. This is focused host evidence; independent review,
contribution commit and updated normal App physical confirmation are pending.
No release version, publication or completed Phase state is introduced.

Independent focused read-only review by /root/text_add_focus_review_20261111,
GPT-6.1 Sol/high, returned PASS with no Current Boundary Blocker, Hygiene or
Development Candidate. Caller-owned focus, null-default compatibility, ordinary
input and node lifetime were accepted against the actual15-case evidence.
The parent built the consuming normal Android build8 successfully; that build
is distinct from physical confirmation and from a TFAF Phase release.

The consuming normal Android build8 was installed as a data-retaining update.
The human confirmed disconnected icon launch followed by Add puts the cursor
in the new field and opens the keyboard. This is the consuming App/Fold result,
not an iPhone installation or a common-framework Phase completion.
