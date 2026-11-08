cmake_minimum_required(VERSION 3.15...3.31)
project(ZOSNativeProbe C)

if(NOT DEFINED EXPECTED_POINTER_SIZE OR NOT DEFINED EXPECTED_CHAR_CODE)
  message(FATAL_ERROR "EXPECTED_POINTER_SIZE and EXPECTED_CHAR_CODE are required")
endif()
if(NOT CMAKE_C_COMPILER_ID STREQUAL "IBMClang")
  message(FATAL_ERROR "Expected IBMClang, detected ${CMAKE_C_COMPILER_ID}")
endif()

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED TRUE)
include(CheckCSourceCompiles)
check_c_source_compiles(
  "
  typedef char check_pointer_size[sizeof(void *) == ${EXPECTED_POINTER_SIZE} ? 1 : -1];
  typedef char check_character_set['A' == ${EXPECTED_CHAR_CODE} ? 1 : -1];
  int main(void) { return 0; }
  "
  NATIVE_MODE_COMPILES
)
if(NOT NATIVE_MODE_COMPILES)
  message(FATAL_ERROR "Compiler pointer size or character set does not match the requested mode")
endif()
if(NOT CMAKE_C_SIZEOF_DATA_PTR EQUAL EXPECTED_POINTER_SIZE)
  message(
    FATAL_ERROR
    "CMake reports ${CMAKE_C_SIZEOF_DATA_PTR}-byte pointers; compiler uses ${EXPECTED_POINTER_SIZE}"
  )
endif()
if(NOT CMAKE_C_BYTE_ORDER STREQUAL "BIG_ENDIAN")
  message(FATAL_ERROR "Expected big-endian z/OS, detected ${CMAKE_C_BYTE_ORDER}")
endif()
message(STATUS "Verified character code ${EXPECTED_CHAR_CODE}, ${EXPECTED_POINTER_SIZE}-byte pointers and big-endian ABI")
