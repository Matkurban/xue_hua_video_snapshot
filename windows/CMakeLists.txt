# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "xue_hua_video_snapshot")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.31)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "xue_hua_video_snapshot_plugin")

set(SHARED_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../shared/cpp")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "xue_hua_video_snapshot_plugin.cpp"
  "xue_hua_video_snapshot_plugin.h"
  "${SHARED_CPP_DIR}/video_decoder_api.cpp"
  "${SHARED_CPP_DIR}/mpv_async_runtime.cc"
  "${SHARED_CPP_DIR}/mpv_session_decoder.cc"
  "${SHARED_CPP_DIR}/mpv_video_decoder_host_api.cc"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/xue_hua_video_snapshot/xue_hua_video_snapshot_plugin_c_api.h"
  "xue_hua_video_snapshot_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Treat source files as UTF-8 to avoid C4819 warnings with Chinese comments.
target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8)

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE
  FLUTTER_PLUGIN_IMPL
  NOMINMAX
  WIN32_LEAN_AND_MEAN
)

# libmpv SDK location. Expected layout:
#   ${MPV_DIR}/include/mpv/*.h
#   ${MPV_DIR}/libmpv.dll.a      (or mpv.lib)
#   ${MPV_DIR}/libmpv-2.dll      (runtime, bundled with plugin)
if(NOT DEFINED MPV_DIR)
  if(DEFINED ENV{MPV_DIR})
    set(MPV_DIR "$ENV{MPV_DIR}")
  else()
    set(MPV_DIR "${CMAKE_CURRENT_SOURCE_DIR}/mpv-dev")
  endif()
endif()
set(MPV_DIR "${MPV_DIR}" CACHE PATH "Path to the libmpv SDK")

set(_XHVS_MPV_DEFAULT_URL
  "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20260417/mpv-dev-x86_64-20260417-git-c865008.7z")
set(_XHVS_MPV_DEFAULT_SHA256
  "a50490e08b93476191dce06f762bac73f4621d1e47a7b73f4ce7714e3fdb86d0")
set(MPV_DOWNLOAD_URL "${_XHVS_MPV_DEFAULT_URL}"
    CACHE STRING "URL of the libmpv dev archive to auto-download when MPV_DIR is missing")
set(MPV_DOWNLOAD_SHA256 "${_XHVS_MPV_DEFAULT_SHA256}"
    CACHE STRING "Expected SHA256 of the libmpv dev archive (leave empty to skip verification)")

if(NOT EXISTS "${MPV_DIR}/include/mpv/client.h")
  if(NOT MPV_DOWNLOAD_URL)
    message(FATAL_ERROR
      "libmpv SDK not found at ${MPV_DIR} and MPV_DOWNLOAD_URL is empty. "
      "Set -DMPV_DIR=<path to mpv-dev SDK> or -DMPV_DOWNLOAD_URL=<archive url>.")
  endif()

  get_filename_component(_XHVS_ARCHIVE_NAME "${MPV_DOWNLOAD_URL}" NAME)
  set(_XHVS_ARCHIVE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${_XHVS_ARCHIVE_NAME}")

  if(NOT EXISTS "${_XHVS_ARCHIVE_PATH}")
    message(STATUS "libmpv SDK not found at ${MPV_DIR}")
    message(STATUS "Downloading libmpv SDK from ${MPV_DOWNLOAD_URL}")
    set(_XHVS_DL_ARGS
      "${MPV_DOWNLOAD_URL}"
      "${_XHVS_ARCHIVE_PATH}"
      SHOW_PROGRESS
      TLS_VERIFY ON
      STATUS _XHVS_DL_STATUS)
    if(MPV_DOWNLOAD_SHA256)
      list(APPEND _XHVS_DL_ARGS EXPECTED_HASH "SHA256=${MPV_DOWNLOAD_SHA256}")
    endif()
    file(DOWNLOAD ${_XHVS_DL_ARGS})
    list(GET _XHVS_DL_STATUS 0 _XHVS_DL_CODE)
    if(NOT _XHVS_DL_CODE EQUAL 0)
      list(GET _XHVS_DL_STATUS 1 _XHVS_DL_MSG)
      file(REMOVE "${_XHVS_ARCHIVE_PATH}")
      message(FATAL_ERROR
        "Failed to download libmpv SDK from ${MPV_DOWNLOAD_URL}: ${_XHVS_DL_MSG}. "
        "Download it manually and set -DMPV_DIR=<path>.")
    endif()
  endif()

  file(MAKE_DIRECTORY "${MPV_DIR}")
  message(STATUS "Extracting libmpv SDK into ${MPV_DIR}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xf "${_XHVS_ARCHIVE_PATH}"
    WORKING_DIRECTORY "${MPV_DIR}"
    RESULT_VARIABLE _XHVS_TAR_RC
  )
  if(NOT _XHVS_TAR_RC EQUAL 0)
    message(FATAL_ERROR
      "Failed to extract libmpv archive '${_XHVS_ARCHIVE_PATH}' (rc=${_XHVS_TAR_RC}).")
  endif()
endif()

if(NOT EXISTS "${MPV_DIR}/include/mpv/client.h")
  message(FATAL_ERROR
    "libmpv headers still not found under ${MPV_DIR}/include/mpv.")
endif()

find_library(MPV_LIBRARY
  NAMES mpv libmpv libmpv.dll
  PATHS "${MPV_DIR}" "${MPV_DIR}/lib"
  NO_DEFAULT_PATH
)
if(NOT MPV_LIBRARY)
  message(FATAL_ERROR
    "libmpv import library not found under ${MPV_DIR}.")
endif()

find_file(MPV_RUNTIME_DLL
  NAMES libmpv-2.dll mpv-2.dll libmpv-1.dll mpv-1.dll
  PATHS "${MPV_DIR}" "${MPV_DIR}/bin"
  NO_DEFAULT_PATH
)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${SHARED_CPP_DIR}"
  "${MPV_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin
  "${MPV_LIBRARY}")

if(MPV_RUNTIME_DLL)
  set(xue_hua_video_snapshot_bundled_libraries
    "${MPV_RUNTIME_DLL}"
    PARENT_SCOPE
  )
else()
  set(xue_hua_video_snapshot_bundled_libraries
    ""
    PARENT_SCOPE
  )
endif()

# === Tests ===
if (${include_${PROJECT_NAME}_tests})
set(TEST_RUNNER "${PROJECT_NAME}_test")
enable_testing()

include(FetchContent)
if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24")
  cmake_policy(SET CMP0135 NEW)
endif()
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.15.2.zip
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)
set(CMAKE_POLICY_VERSION_MINIMUM 3.5 CACHE STRING "" FORCE)
FetchContent_MakeAvailable(googletest)
unset(CMAKE_POLICY_VERSION_MINIMUM CACHE)

add_executable(${TEST_RUNNER}
  test/xue_hua_video_snapshot_plugin_test.cpp
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${TEST_RUNNER})
target_compile_options(${TEST_RUNNER} PRIVATE /utf-8)
target_compile_definitions(${TEST_RUNNER} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_include_directories(${TEST_RUNNER} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${SHARED_CPP_DIR}"
  "${MPV_DIR}/include")
target_link_libraries(${TEST_RUNNER} PRIVATE flutter_wrapper_plugin
  "${MPV_LIBRARY}")
target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main gmock)
add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  "${FLUTTER_LIBRARY}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
)
if(MPV_RUNTIME_DLL)
  add_custom_command(TARGET ${TEST_RUNNER} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${MPV_RUNTIME_DLL}" $<TARGET_FILE_DIR:${TEST_RUNNER}>
  )
endif()

include(GoogleTest)
gtest_discover_tests(${TEST_RUNNER} DISCOVERY_MODE PRE_TEST)
endif()
