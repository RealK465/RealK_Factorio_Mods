"""Shared pipeline for Factorio art: render rig, post pass, sheets, gates.

Import from anywhere by putting `.claude/skills/factorio-graphics/scripts` on
sys.path. `rig` and `greeble` need Blender (bpy); the rest is system Python
with Pillow + numpy, so post-processing and comparison never wait on a render.
"""

__all__ = ["imaging", "post", "vanilla", "gates", "rig", "greeble"]
