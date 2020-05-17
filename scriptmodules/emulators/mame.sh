#!/usr/bin/env bash

# This file is part of The RetroPie Project
#
# The RetroPie Project is the legal property of its developers, whose names are
# too numerous to list here. Please refer to the COPYRIGHT.md file distributed with this source.
#
# See the LICENSE.md file at the top-level directory of this distribution and
# at https://raw.githubusercontent.com/RetroPie/RetroPie-Setup/master/LICENSE.md
#

rp_module_id="mame"
rp_module_desc="MAME emulator"
rp_module_help="ROM Extensions: .zip .7z\n\nCopy your MAME roms to either $romdir/mame or\n$romdir/arcade"
rp_module_licence="GPL2 https://github.com/mamedev/mame/blob/master/COPYING"
rp_module_section="exp"
rp_module_flags="!mali !armv6"

function _latest_ver_mame() {
    wget -qO- https://api.github.com/repos/mamedev/mame/releases/latest | grep -m 1 tag_name | cut -d\" -f4
}

function _get_binary_name_mame() {
    # The MAME executable on 64-bit systems is called mame64 instead of mame. Rename it back to mame.
    if isPlatform "64bit"; then
        echo 'mame64'
    else
        echo 'mame'
    fi
}

function depends_mame() {
    if compareVersions $__gcc_version lt 6.0.0; then
        md_ret_errors+=("Sorry, you need an OS with gcc 6.0 or newer to compile mame")
        return 1
    fi

    # Install required libraries required for compilation and running
    # Note: libxi-dev is required as of v0.210, because of flag changes for XInput
    getDepends libfontconfig1-dev qt5-default libsdl2-ttf-dev libxinerama-dev libxi-dev
}

function sources_mame() {
    gitPullOrClone "$md_build" https://github.com/mamedev/mame.git "$(_latest_ver_mame)"
}

function build_mame() {
    # More memory is required for x86 platforms
    if isPlatform "64bit"; then
        rpSwap on 8192
    else
        rpSwap on 4096
    fi

    # Compile MAME
    local params=(NOWERROR=1 ARCHOPTS=-U_FORTIFY_SOURCE)
    make "${params[@]}"

    local binary_name="$(_get_binary_name_${md_id})"
    strip "${binary_name}"

    rpSwap off
    md_ret_require="$md_build/${binary_name}"
}

function install_mame() {
    md_ret_files=(
        'artwork'
        'bgfx'
        'ctrlr'
        'docs'
        'hash'
        'hlsl'
        'ini'
        'language'
        "$(_get_binary_name_${md_id})"
        'plugins'
        'roms'
        'samples'
        'uismall.bdf'
        'COPYING'
    )
}

function configure_mame() {
    if [[ "$md_mode" == "install" ]]; then
        local system="mame"
        mkRomDir "arcade"
        mkRomDir "$system"

        # Create required MAME directories underneath the ROM directory
        local mame_sub_dir
        for mame_sub_dir in artwork cfg comments diff inp nvram samples scores snap sta; do
            mkRomDir "$system/$mame_sub_dir"
        done

        # Create a BIOS directory, where people will be able to store their BIOS files, separate from ROMs
        mkUserDir "$biosdir/$system"

        # Create the configuration directory for the MAME ini files
        moveConfigDir "$home/.mame" "$md_conf_root/$system"

        # Create new INI files if they do not already exist
        # Create MAME config file
        local temp_ini_mame="$(mktemp)"

        iniConfig " " "" "$temp_ini_mame"
        iniSet "rompath"            "$romdir/$system;$romdir/arcade;$biosdir/$system"
        iniSet "hashpath"           "$md_inst/hash"
        iniSet "samplepath"         "$romdir/$system/samples;$romdir/arcade/samples"
        iniSet "artpath"            "$romdir/$system/artwork;$romdir/arcade/artwork"
        iniSet "ctrlrpath"          "$md_inst/ctrlr"
        iniSet "pluginspath"        "$md_inst/plugins"
        iniSet "languagepath"       "$md_inst/language"

        iniSet "cfg_directory"      "$romdir/$system/cfg"
        iniSet "nvram_directory"    "$romdir/$system/nvram"
        iniSet "input_directory"    "$romdir/$system/inp"
        iniSet "state_directory"    "$romdir/$system/sta"
        iniSet "snapshot_directory" "$romdir/$system/snap"
        iniSet "diff_directory"     "$romdir/$system/diff"
        iniSet "comment_directory"  "$romdir/$system/comments"

        iniSet "skip_gameinfo" "1"
        iniSet "plugin" "hiscore"
        iniSet "samplerate" "44100"

        # Raspberry Pi 4 comes with the OpenGL driver enabled and shows reasonable performance
        # Other Raspberry Pi's show improved performance using accelerated mode
        if isPlatform "rpi4"; then
            iniSet "video" "opengl"
        elif isPlatform "rpi"; then
            iniSet "video" "accel"
        fi

        copyDefaultConfig "$temp_ini_mame" "$md_conf_root/$system/mame.ini"
        rm "$temp_ini_mame"

        # Create MAME UI config file
        local temp_ini_ui="$(mktemp)"
        iniConfig " " "" "$temp_ini_ui"
        iniSet "scores_directory" "$romdir/$system/scores"
        copyDefaultConfig "$temp_ini_ui" "$md_conf_root/$system/ui.ini"
        rm "$temp_ini_ui"

        # Create MAME Plugin config file
        local temp_ini_plugin="$(mktemp)"
        iniConfig " " "" "$temp_ini_plugin"
        iniSet "hiscore" "1"
        copyDefaultConfig "$temp_ini_plugin" "$md_conf_root/$system/plugin.ini"
        rm "$temp_ini_plugin"

        # Create MAME Hi Score config file
        local temp_ini_hiscore="$(mktemp)"
        iniConfig " " "" "$temp_ini_hiscore"
        iniSet "hi_path" "$romdir/$system/scores"
        copyDefaultConfig "$temp_ini_hiscore" "$md_conf_root/$system/hiscore.ini"
        rm "$temp_ini_hiscore"
    fi

    local binary_name="$(_get_binary_name_${md_id})"
    addEmulator 0 "$md_id" "arcade" "$md_inst/${binary_name} %BASENAME%"
    addEmulator 1 "$md_id" "$system" "$md_inst/${binary_name} %BASENAME%"

    addSystem "arcade" "$rp_module_desc" ".zip .7z"
    addSystem "$system" "$rp_module_desc" ".zip .7z"
}
