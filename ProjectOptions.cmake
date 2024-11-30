include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(testcmaketemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(testcmaketemplate_setup_options)
  option(testcmaketemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(testcmaketemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    testcmaketemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    testcmaketemplate_ENABLE_HARDENING
    OFF)

  testcmaketemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR testcmaketemplate_PACKAGING_MAINTAINER_MODE)
    option(testcmaketemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(testcmaketemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(testcmaketemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(testcmaketemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(testcmaketemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(testcmaketemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(testcmaketemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(testcmaketemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(testcmaketemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(testcmaketemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(testcmaketemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(testcmaketemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(testcmaketemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(testcmaketemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(testcmaketemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(testcmaketemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(testcmaketemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(testcmaketemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(testcmaketemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      testcmaketemplate_ENABLE_IPO
      testcmaketemplate_WARNINGS_AS_ERRORS
      testcmaketemplate_ENABLE_USER_LINKER
      testcmaketemplate_ENABLE_SANITIZER_ADDRESS
      testcmaketemplate_ENABLE_SANITIZER_LEAK
      testcmaketemplate_ENABLE_SANITIZER_UNDEFINED
      testcmaketemplate_ENABLE_SANITIZER_THREAD
      testcmaketemplate_ENABLE_SANITIZER_MEMORY
      testcmaketemplate_ENABLE_UNITY_BUILD
      testcmaketemplate_ENABLE_CLANG_TIDY
      testcmaketemplate_ENABLE_CPPCHECK
      testcmaketemplate_ENABLE_COVERAGE
      testcmaketemplate_ENABLE_PCH
      testcmaketemplate_ENABLE_CACHE)
  endif()

  testcmaketemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (testcmaketemplate_ENABLE_SANITIZER_ADDRESS OR testcmaketemplate_ENABLE_SANITIZER_THREAD OR testcmaketemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(testcmaketemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(testcmaketemplate_global_options)
  if(testcmaketemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    testcmaketemplate_enable_ipo()
  endif()

  testcmaketemplate_supports_sanitizers()

  if(testcmaketemplate_ENABLE_HARDENING AND testcmaketemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR testcmaketemplate_ENABLE_SANITIZER_UNDEFINED
       OR testcmaketemplate_ENABLE_SANITIZER_ADDRESS
       OR testcmaketemplate_ENABLE_SANITIZER_THREAD
       OR testcmaketemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${testcmaketemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${testcmaketemplate_ENABLE_SANITIZER_UNDEFINED}")
    testcmaketemplate_enable_hardening(testcmaketemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(testcmaketemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(testcmaketemplate_warnings INTERFACE)
  add_library(testcmaketemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  testcmaketemplate_set_project_warnings(
    testcmaketemplate_warnings
    ${testcmaketemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(testcmaketemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    testcmaketemplate_configure_linker(testcmaketemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  testcmaketemplate_enable_sanitizers(
    testcmaketemplate_options
    ${testcmaketemplate_ENABLE_SANITIZER_ADDRESS}
    ${testcmaketemplate_ENABLE_SANITIZER_LEAK}
    ${testcmaketemplate_ENABLE_SANITIZER_UNDEFINED}
    ${testcmaketemplate_ENABLE_SANITIZER_THREAD}
    ${testcmaketemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(testcmaketemplate_options PROPERTIES UNITY_BUILD ${testcmaketemplate_ENABLE_UNITY_BUILD})

  if(testcmaketemplate_ENABLE_PCH)
    target_precompile_headers(
      testcmaketemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(testcmaketemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    testcmaketemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(testcmaketemplate_ENABLE_CLANG_TIDY)
    testcmaketemplate_enable_clang_tidy(testcmaketemplate_options ${testcmaketemplate_WARNINGS_AS_ERRORS})
  endif()

  if(testcmaketemplate_ENABLE_CPPCHECK)
    testcmaketemplate_enable_cppcheck(${testcmaketemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(testcmaketemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    testcmaketemplate_enable_coverage(testcmaketemplate_options)
  endif()

  if(testcmaketemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(testcmaketemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(testcmaketemplate_ENABLE_HARDENING AND NOT testcmaketemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR testcmaketemplate_ENABLE_SANITIZER_UNDEFINED
       OR testcmaketemplate_ENABLE_SANITIZER_ADDRESS
       OR testcmaketemplate_ENABLE_SANITIZER_THREAD
       OR testcmaketemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    testcmaketemplate_enable_hardening(testcmaketemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
