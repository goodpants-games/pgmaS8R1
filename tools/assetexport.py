#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

ASEPRITE = os.environ.get('ASEPRITE', 'aseprite')
TILED = os.environ.get('TILED', 'tiled')

TMX_BASE_DIRECTORY = os.path.join(os.curdir, 'assets/tiled/maps')
TSX_BASE_DIRECTORY = os.path.join(os.curdir, 'assets/tiled/tilesets')
ASE_INPUTS = os.path.join(os.curdir, 'assets/ase')
ASE_OUTPUTS = os.path.join(os.curdir, 'res/sprites')


def needs_update(src_path: str, dst_path: str) -> bool:
    # first, determine if out_path is out of date
    has_mtime = False
    if os.path.exists(dst_path):
        has_mtime = True
        out_mtime = os.path.getmtime(dst_path)
    
    if has_mtime:
        return os.path.getmtime(src_path) > out_mtime
    else:
        return True

def process_tmx(src_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.join('root/res/maps/',
                            os.path.relpath(os.path.dirname(src_path), TMX_BASE_DIRECTORY),
                            filename + '.lua')

    if not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    print(f'[TMX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-map', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True

def process_tsx(src_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    intermediate_path = os.path.join(os.path.dirname(src_path), filename + '.lua')
    dst_path = os.path.join('root/res/tilesets/',
                            os.path.relpath(os.path.dirname(src_path), TSX_BASE_DIRECTORY),
                            filename + '.lua')

    if not needs_update(src_path, dst_path): return True

    src_path = os.path.normpath(src_path)
    intermediate_path = os.path.normpath(intermediate_path)

    print(f'[TSX] {src_path} => {dst_path}')
    tiled = subprocess.run([TILED, '--export-tileset', 'lua', src_path, intermediate_path])
    if tiled.returncode != 0:
        return False
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    os.replace(intermediate_path, dst_path)
    return True

def scan_tileset_directory(dirpath: str) -> bool:
    for basename in os.listdir(dirpath):
        path = os.path.join(dirpath, basename)

        if os.path.isdir(path) and basename != 'editoronly':
            scan_tileset_directory(dirpath)
        
        else:
            (_, fileext) = os.path.splitext(basename)

            if fileext == '.png':
                dst_path = os.path.join('root/res/tilesets',
                                        os.path.relpath(path, TSX_BASE_DIRECTORY))
                dst_path = os.path.normpath(dst_path)

                if needs_update(path, dst_path):
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    shutil.copy(path, dst_path)
            
            elif fileext == '.tsx':
                process_tsx(path)
    
    return True

def scan_tiled_directory(dirpath: str) -> bool:
    for basename in os.listdir(dirpath):
        path = os.path.normpath(os.path.join(dirpath, basename))
        (filename, fileext) = os.path.splitext(basename)

        if fileext == ".tmx":
            s = process_tmx(path)
            if not s:
                return False
    
    return True
# def process_tiled_directory(dirpath: str) -> bool:
#     success = True

#     for fpath in os.listdir(dirpath):
#         abs_path = os.path.join(dirpath, fpath)

#         if os.path.isdir(abs_path):
#             process_tiled_directory(abs_path)
#         else:
#             (filename, _) = os.path.splitext(rel_path)

#             spr_path = os.path.join(ASE_OUTPUTS, filename + '.spr')
#             if not process_ase(abs_path, spr_path) or not process_normal_map(spr_path):
#                 success = False

#     return success
            
if __name__ == '__main__':
    if not (scan_tiled_directory(TMX_BASE_DIRECTORY) and scan_tileset_directory(TSX_BASE_DIRECTORY)):
        sys.exit(1)    
