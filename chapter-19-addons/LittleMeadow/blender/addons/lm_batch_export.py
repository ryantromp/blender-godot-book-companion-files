bl_info = {
    "name": "Little Meadow Batch Export",
    "author": "Little Meadow book",
    "version": (1, 0, 0),
    "blender": (5, 2, 0),
    "location": "3D Viewport > Sidebar (N) > Little Meadow",
    "description": "Export every asset inside COL_export to its own .glb file",
    "category": "Import-Export",
}

import os
import bpy
from bpy.props import BoolProperty, PointerProperty, StringProperty
from bpy.types import Operator, Panel, PropertyGroup


class LMExportSettings(PropertyGroup):
    export_dir: StringProperty(
        name="Folder", subtype='DIR_PATH', default="//../export/",
        options={'PATH_SUPPORTS_BLEND_RELATIVE'})
    source: StringProperty(name="Source", default="COL_export")
    at_origin: BoolProperty(name="Export at Origin", default=True)
    animations: BoolProperty(name="Animations", default=True)


def find_jobs(source_name):
    """The child collections of the source collection, or None if it does not exist."""
    root = bpy.data.collections.get(source_name)
    return None if root is None else list(root.children)


class LM_OT_batch_export(Operator):
    """Write each child collection of the source collection to its own .glb file"""
    bl_idname = "lm_export.batch_export"
    bl_label = "Export to glTF"

    dry_run: BoolProperty(name="Dry Run", default=False, options={'SKIP_SAVE'})

    @classmethod
    def poll(cls, context):
        return context.mode == 'OBJECT'

    def execute(self, context):
        s = context.scene.lm_export
        jobs = find_jobs(s.source)
        if not jobs:
            self.report({'ERROR'}, "Nothing to export: " + s.source + " is missing or empty")
            return {'CANCELLED'}
        folder = bpy.path.abspath(s.export_dir)
        if folder.startswith("//"):
            self.report({'ERROR'}, "Save the .blend file first: the folder is relative to it")
            return {'CANCELLED'}
        if self.dry_run:
            self.report({'INFO'}, "Would write: " + ", ".join(c.name for c in jobs))
            return {'FINISHED'}
        folder = os.path.normpath(folder)
        os.makedirs(folder, exist_ok=True)
        for coll in jobs:
            bpy.ops.export_scene.gltf(
                filepath=os.path.join(folder, bpy.path.clean_name(coll.name) + ".glb"),
                export_format='GLB', collection=coll.name, at_collection_center=s.at_origin,
                export_apply=True, export_yup=True, export_cameras=False, export_lights=False,
                export_animations=s.animations, export_image_format='NONE', export_vertex_color='ACTIVE',
                export_def_bones=True, export_anim_slide_to_zero=True, export_anim_single_armature=False)
        self.report({'INFO'}, "Wrote %d files to %s" % (len(jobs), folder))
        return {'FINISHED'}


class LM_PT_batch_export(Panel):
    bl_label = "Batch Export"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Little Meadow"

    def draw(self, context):
        s = context.scene.lm_export
        col = self.layout.column()
        for prop in ("export_dir", "source", "at_origin", "animations"):
            col.prop(s, prop)
        jobs = find_jobs(s.source)
        box = self.layout.box()
        if jobs is None:
            box.label(text="No collection named " + s.source, icon='ERROR')
        else:
            box.label(text="%d files will be written" % len(jobs))
            for coll in jobs[:12]:
                box.label(text=coll.name + ".glb", icon='OUTLINER_COLLECTION')
        row = self.layout.row(align=True)
        row.operator("lm_export.batch_export", text="Export", icon='EXPORT')
        row.operator("lm_export.batch_export", text="Dry Run").dry_run = True


classes = (LMExportSettings, LM_OT_batch_export, LM_PT_batch_export)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.lm_export = PointerProperty(type=LMExportSettings)


def unregister():
    del bpy.types.Scene.lm_export
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
