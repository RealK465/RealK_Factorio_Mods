"""Shared pipeline for Factorio art: render rig, post pass, sheets, gates.

Import from anywhere by putting `.claude/skills/factorio-graphics/scripts` on
sys.path. `rig`, `greeble` and `parts` need Blender (bpy); the rest is system
Python with Pillow + numpy, so post-processing and comparison never wait on a
render.

Nothing is imported eagerly here, deliberately: `from factorio_render import
gates` has to keep working in system Python, and it would not if this module
pulled in the bpy-only half.
"""

__all__ = ["imaging", "post", "vanilla", "gates", "rig", "greeble", "parts"]
