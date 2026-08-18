function(avif_build_local_dav1d)
    if(EXISTS "${AVIF_SOURCE_DIR}/ext/dav1d")
        message(STATUS "libavif(AVIF_CODEC_DAV1D=LOCAL): ext/dav1d found, using as SOURCE_DIR")
        set(source_dir "${AVIF_SOURCE_DIR}/ext/dav1d")
    else()
        message(
            FATAL_ERROR
            "libavif(AVIF_CODEC_DAV1D=LOCAL): required vendored source is missing at ${AVIF_SOURCE_DIR}/ext/dav1d"
        )
    endif()

    # Meson emits source paths relative to its deeply nested native-assets
    # build directory. NASM on Windows cannot open those paths before they are
    # normalized, so stage the source beside the build directory.
    if(CMAKE_HOST_WIN32)
        set(staged_source_dir "${FETCHCONTENT_BASE_DIR}/dav1d-src")
        file(COPY "${source_dir}/" DESTINATION "${staged_source_dir}")
        set(source_dir "${staged_source_dir}")
    endif()

    find_program(NINJA_EXECUTABLE NAMES ninja ninja-build REQUIRED)
    find_program(MESON_EXECUTABLE meson REQUIRED)

    set(PATH $ENV{PATH})
    if(CMAKE_HOST_WIN32)
        string(REPLACE ";" "\$<SEMICOLON>" PATH "${PATH}")
    endif()
    if(ANDROID_TOOLCHAIN_ROOT)
        set(PATH "${ANDROID_TOOLCHAIN_ROOT}/bin$<IF:$<BOOL:${CMAKE_HOST_WIN32}>,$<SEMICOLON>,:>${PATH}")
    endif()

    # Passing the complete semicolon-delimited Windows PATH through
    # ExternalProject_Add expands it into separate command arguments. Prepend
    # only the Android toolchain directory and let the child inherit the rest.
    if(CMAKE_HOST_WIN32 AND ANDROID_TOOLCHAIN_ROOT)
        set(
            DAV1D_ENV_COMMAND
            ${CMAKE_COMMAND} -E env --modify "PATH=path_list_prepend:${ANDROID_TOOLCHAIN_ROOT}/bin" --
        )
    else()
        set(DAV1D_ENV_COMMAND ${CMAKE_COMMAND} -E env "PATH=${PATH}")
    endif()

    if(ANDROID)
        list(APPEND CMAKE_PROGRAM_PATH "${ANDROID_TOOLCHAIN_ROOT}/bin")

        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "armv7-a")
            set(android_arch "arm")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "aarch64")
            set(android_arch "aarch64")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
            set(android_arch "x86_64")
        else()
            set(android_arch "x86")
        endif()

        set(CROSS_FILE "${source_dir}/package/crossfiles/${android_arch}-android.meson")
        # The vendored Android cross files use the Windows NDK wrapper names
        # (*.cmd and *.exe). Linux NDK tool names have no suffix, so generate
        # a host-appropriate copy without modifying the vendored source.
        if(NOT CMAKE_HOST_WIN32)
            file(READ "${CROSS_FILE}" android_cross_file_contents)
            string(REPLACE ".cmd'" "'" android_cross_file_contents "${android_cross_file_contents}")
            string(REPLACE ".exe'" "'" android_cross_file_contents "${android_cross_file_contents}")
            set(CROSS_FILE "${PROJECT_BINARY_DIR}/crossfile-${android_arch}-android.meson")
            file(WRITE "${CROSS_FILE}" "${android_cross_file_contents}")
        endif()
    elseif(APPLE)
        # Meson needs a cross file whenever CMake targets an Apple SDK, even
        # when host and target share the same CPU architecture.
        if(CMAKE_CROSSCOMPILING)
            if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
                set(cross_system_name "darwin")
                set(cross_system_subsystem "subsystem = 'ios'")
            else()
                string(TOLOWER "${CMAKE_SYSTEM_NAME}" cross_system_name)
                set(cross_system_subsystem "")
            endif()
            if(CMAKE_C_BYTE_ORDER STREQUAL "BIG_ENDIAN")
                set(cross_system_endian "big")
            else()
                set(cross_system_endian "little")
            endif()
            if(CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
                set(cross_system_processor "aarch64")
            else()
                set(cross_system_processor "${CMAKE_SYSTEM_PROCESSOR}")
            endif()
            # The cmake crate supplies the complete Apple target, SDK, and
            # deployment flags in CMAKE_C_FLAGS. Preserve that target exactly
            # when Meson builds dav1d; reconstructing it from the architecture
            # alone makes iOS simulator objects target macOS.
            separate_arguments(cross_cmake_cflags NATIVE_COMMAND "${CMAKE_C_FLAGS}")
            set(cross_c_args "")
            foreach(cross_flag IN LISTS cross_cmake_cflags)
                string(REPLACE "\\" "\\\\" cross_flag "${cross_flag}")
                string(REPLACE "'" "\\'" cross_flag "${cross_flag}")
                if(cross_c_args)
                    string(APPEND cross_c_args ", ")
                endif()
                string(APPEND cross_c_args "'${cross_flag}'")
            endforeach()

            set(CROSS_FILE "${PROJECT_BINARY_DIR}/crossfile-apple.meson")
            configure_file("cmake/Meson/crossfile-apple.meson.in" "${CROSS_FILE}")
        endif()
    endif()

    if(CROSS_FILE)
        set(EXTRA_ARGS "--cross-file=${CROSS_FILE}")
    endif()

    set(build_dir "${FETCHCONTENT_BASE_DIR}/dav1d-build")
    set(install_dir "${FETCHCONTENT_BASE_DIR}/dav1d-install")

    if(ANDROID_ABI)
        set(build_dir "${build_dir}/${ANDROID_ABI}")
        set(install_dir "${install_dir}/${ANDROID_ABI}")
    endif()
    if(CMAKE_HOST_WIN32 AND ANDROID)
        file(TO_NATIVE_PATH "${install_dir}" meson_install_dir)
        set(meson_prefix "/")
        set(
            DAV1D_INSTALL_ENV_COMMAND
            ${CMAKE_COMMAND} -E env
            --modify "PATH=path_list_prepend:${ANDROID_TOOLCHAIN_ROOT}/bin"
            --modify "DESTDIR=set:${meson_install_dir}" --
        )
    else()
        set(meson_install_dir "${install_dir}")
        set(meson_prefix "${meson_install_dir}")
        set(DAV1D_INSTALL_ENV_COMMAND ${DAV1D_ENV_COMMAND})
    endif()
    file(MAKE_DIRECTORY ${install_dir}/include)

    ExternalProject_Add(
        dav1d
        LOG_DIR "${build_dir}"
        STAMP_DIR "${build_dir}"
        TMP_DIR "${build_dir}"
        SOURCE_DIR "${source_dir}"
        BINARY_DIR "${build_dir}"
        INSTALL_DIR "${install_dir}"
        LIST_SEPARATOR |
        UPDATE_COMMAND ""
        CONFIGURE_COMMAND
            ${DAV1D_ENV_COMMAND} ${MESON_EXECUTABLE} setup --buildtype=release --default-library=static
            --prefix=${meson_prefix} --libdir=lib -Denable_asm=true -Denable_tools=false -Denable_examples=false
            -Denable_tests=false ${EXTRA_ARGS} <SOURCE_DIR>
        BUILD_COMMAND ${DAV1D_ENV_COMMAND} ${NINJA_EXECUTABLE} -C <BINARY_DIR>
        INSTALL_COMMAND ${DAV1D_INSTALL_ENV_COMMAND} ${NINJA_EXECUTABLE} -C <BINARY_DIR> install
        BUILD_BYPRODUCTS <INSTALL_DIR>/lib/libdav1d.a
    )

    add_library(dav1d::dav1d STATIC IMPORTED)
    set_target_properties(dav1d::dav1d PROPERTIES IMPORTED_LOCATION ${install_dir}/lib/libdav1d.a AVIF_LOCAL ON)
    target_include_directories(dav1d::dav1d INTERFACE "${install_dir}/include")
    target_link_directories(dav1d::dav1d INTERFACE ${install_dir}/lib)
    add_dependencies(dav1d::dav1d dav1d)
endfunction()

set(AVIF_DAV1D_BUILD_DIR "${AVIF_SOURCE_DIR}/ext/dav1d/build")
# If ${ANDROID_ABI} is set, look for the library under that subdirectory.
if(DEFINED ANDROID_ABI)
    set(AVIF_DAV1D_BUILD_DIR "${AVIF_DAV1D_BUILD_DIR}/${ANDROID_ABI}")
endif()
set(LIB_FILENAME "${AVIF_DAV1D_BUILD_DIR}/src/libdav1d${CMAKE_STATIC_LIBRARY_SUFFIX}")
if(NOT EXISTS "${LIB_FILENAME}" AND NOT "${CMAKE_STATIC_LIBRARY_SUFFIX}" STREQUAL ".a")
    # On windows, meson will produce a libdav1d.a instead of the expected libdav1d.dll/.lib.
    # See https://github.com/mesonbuild/meson/issues/8153.
    set(LIB_FILENAME "${AVIF_DAV1D_BUILD_DIR}/src/libdav1d.a")
endif()
if(EXISTS "${LIB_FILENAME}")
    message(STATUS "libavif(AVIF_CODEC_DAV1D=LOCAL): compiled library found at ${LIB_FILENAME}")
    add_library(dav1d::dav1d STATIC IMPORTED)
    set_target_properties(dav1d::dav1d PROPERTIES IMPORTED_LOCATION ${LIB_FILENAME} AVIF_LOCAL ON)
    target_include_directories(
        dav1d::dav1d INTERFACE "${AVIF_DAV1D_BUILD_DIR}" "${AVIF_DAV1D_BUILD_DIR}/include"
                               "${AVIF_DAV1D_BUILD_DIR}/include/dav1d" "${AVIF_SOURCE_DIR}/ext/dav1d/include"
    )
else()
    message(STATUS "libavif(AVIF_CODEC_DAV1D=LOCAL): compiled library not found at ${LIB_FILENAME}; using ExternalProject")

    avif_build_local_dav1d()
endif()

if(EXISTS "${AVIF_SOURCE_DIR}/ext/dav1d")
    set_target_properties(dav1d::dav1d PROPERTIES FOLDER "ext/dav1d")
endif()
