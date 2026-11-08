# zopen CMake 4.4.5 forces IBM-Clang's ABI probe to -m32. Keep its ASCII
# literals for binary scanning, but preserve the caller's requested ABI.
set(module "${CMAKE_ROOT}/Modules/CMakeDetermineCompilerABI.cmake")
file(READ "${module}" contents)
set(
  old
  [=[        get_filename_component(COMPILER_BASENAME "${CMAKE_${lang}_COMPILER}" NAME)
        if(COMPILER_BASENAME STREQUAL "ibm-clang" OR COMPILER_BASENAME STREQUAL "ibm-clang++")
          string(APPEND COMPILE_DEFINITIONS " -m32 -fzos-le-char-mode=ascii")
          list(APPEND LINK_OPTIONS " -m32")
        else()
          string(APPEND COMPILE_DEFINITIONS " -fzos-le-char-mode=ascii")
        endif()]=]
)
string(FIND "${contents}" "${old}" position)
if(position EQUAL -1)
  message(FATAL_ERROR "Cannot find the expected zopen ABI override in ${module}")
endif()
string(
  REPLACE "${old}" [=[        list(APPEND COMPILE_DEFINITIONS "-fzos-le-char-mode=ascii")]=]
          contents "${contents}"
)
file(WRITE "${module}" "${contents}")
message(STATUS "Removed forced -m32 from ${module}; retained ASCII ABI markers")
