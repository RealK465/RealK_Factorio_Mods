Earlier states of the machine that git history does not hold.

`quality_recycler_gen-v0-original.py` is the 2026-09-10 model as it stood in the
working tree when the 2026-09-11 rebuild began -- uncommitted, so it is not in
history, and it is the only copy of the horizontal-drum machine that shipped
before direction B replaced it.

`*-v2.py` are the v2 generators as they stood when the v3 pass began later the
same day. v2 itself is commit 57acdf1; these six differ from it (the lens
recalibration and paint-over settings landed after that commit), so they are
kept. `qr_layout` and `render_entity` were identical to the commit and are
not duplicated here.

No `.blend` is kept for either: that file is a cache the generator rebuilds in
seconds, and a megabyte of binary that nothing reads is not worth a commit.
Run the generator to get the scene back.
