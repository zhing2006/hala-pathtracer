import os
import re
import subprocess


# Find all *_color.pfm files in the specified directory.
def find_color_files(directory):
    color_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if re.search(r'_color.pfm$', file):
                color_files.append(os.path.join(root, file))
    return color_files


# Find albedo and normal files corresponding to the *_color.pfm file.
def find_albedo_normal_files(color_file):
    albedo_file = color_file.replace('_color.pfm', '_albedo.pfm')
    normal_file = color_file.replace('_color.pfm', '_normal.pfm')
    # Check if the albedo and normal files exist.
    if not os.path.exists(albedo_file) or not os.path.exists(normal_file):
        return None, None
    return albedo_file, normal_file


# Call oidnDenoise to output final image.
def denoise(color_file, albedo_file, normal_file):
    final_file = color_file.replace('_color.pfm', '_final.pfm')
    subprocess.run(['oidnDenoise', '--hdr', color_file, '--alb', albedo_file, '--nrm', normal_file, '--output', final_file])
    return final_file


if __name__ == '__main__':
    # Find all *_color.pfm files in the specified directory.
    color_files = find_color_files('./out/')
    for color_file in color_files:
        albedo_file, normal_file = find_albedo_normal_files(color_file)
        if albedo_file is None or normal_file is None:
            continue
        print(f'Color file: {color_file}')
        print(f'Albedo file: {albedo_file}')
        print(f'Normal file: {normal_file}')
        final_file = denoise(color_file, albedo_file, normal_file)
        print(f'Final file: {final_file}')