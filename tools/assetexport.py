#!/usr/bin/env python3
import os
import subprocess
import shutil
import sys

ASEPRITE = os.environ.get('ASEPRITE', 'aseprite')
TILED = os.environ.get('TILED', 'tiled')

TMX_BASE_DIRECTORY = os.path.join(os.curdir, 'assets/tiled/maps')
TSX_BASE_DIRECTORY = os.path.join(os.curdir, 'assets/tiled/tilesets')
ASE_BASE_DIRECTORY = os.path.join(os.curdir, 'assets/sprites')

ASEPRITE_ARGS = ['--sheet-pack', '--inner-padding', '1', '--trim',
                 '--merge-duplicates', '--format', 'json-array', '--list-tags']

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

def process_ase(src_path: str) -> bool:
    (filename, _) = os.path.splitext(os.path.basename(src_path))
    dst_json_path = os.path.join('root/res/sprites/',
                                 os.path.relpath(os.path.dirname(src_path), ASE_BASE_DIRECTORY),
                                 filename + '.json')
    dst_png_path = os.path.splitext(dst_json_path)[0] + '.png'

    if not needs_update(src_path, dst_json_path): return True

    src_path = os.path.normpath(src_path)
    dst_json_path = os.path.normpath(dst_json_path)
    dst_png_path = os.path.normpath(dst_png_path)

    print(f'[ASE] {src_path} => {dst_json_path}')
    os.makedirs(os.path.dirname(dst_json_path), exist_ok=True)
    ase = subprocess.run([ASEPRITE,
                          '-b', src_path,
                          '--data', dst_json_path,
                          '--sheet', dst_png_path] + ASEPRITE_ARGS)
    if ase.returncode != 0:
        return False
    
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
                    print(f"[CPY] {path} => {dst_path}")
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    shutil.copy(path, dst_path)
            
            elif fileext == '.tsx':
                if not process_tsx(path):
                    return False
    
    return True

def scan_tiled_directory(dirpath: str) -> bool:
    for basename in os.listdir(dirpath):
        path = os.path.join(dirpath, basename)

        if os.path.isdir(path) and basename != 'editoronly':
            scan_tiled_directory(path)

        else:
            (filename, fileext) = os.path.splitext(basename)

            if fileext == ".tmx":
                s = process_tmx(os.path.normpath(path))
                if not s:
                    return False
    
    return True

def scan_ase_directory(dirpath: str) -> bool:
    for basename in os.listdir(dirpath):
        path = os.path.join(dirpath, basename)

        if os.path.isdir(path) and basename != 'editoronly':
            scan_ase_directory(path)

        else:
            if not process_ase(path):
                return False
    
    return True

def main():
    s = False
    while True:
        if not scan_tiled_directory(TMX_BASE_DIRECTORY):
            break

        if not scan_tileset_directory(TSX_BASE_DIRECTORY):
            break

        if not scan_ase_directory(ASE_BASE_DIRECTORY):
            break

        s = True
        break
    
    if not s: sys.exit(1)

if __name__ == '__main__': main()