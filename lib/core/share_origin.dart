import 'package:flutter/material.dart';

/// The rect [ShareParams.sharePositionOrigin] needs. share_plus's own doc
/// says this is only for the iPad/Mac popover anchor and is "ignored on
/// other platforms" — but its iOS implementation actually throws a
/// PlatformException ("sharePositionOrigin: argument must be set") for any
/// share() call that omits it, iPhone included, rather than silently
/// ignoring a missing value the way the doc promises. Always passing this
/// (not just when running on iPad) is what actually avoids that.
///
/// Falls back to null (letting share_plus fail again as before) only if
/// [context] has no RenderBox to anchor from at all, which shouldn't happen
/// for a context reached from inside a normal widget build.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
