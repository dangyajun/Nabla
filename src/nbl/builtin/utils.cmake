macro(LIST_BUILTIN_RESOURCE _BUNDLE_NAME_ _LBR_PATH_)
	set(_OPTIONAL_ALIAS_ "${ARGV2}")
	
	list(APPEND ${_BUNDLE_NAME_} "${_LBR_PATH_}")
	set(${_BUNDLE_NAME_} ${${_BUNDLE_NAME_}} PARENT_SCOPE) # override
	
	list(APPEND _LBR_${_BUNDLE_NAME_}_ "${_LBR_PATH_},${_OPTIONAL_ALIAS_}")
	set(_LBR_${_BUNDLE_NAME_}_ ${_LBR_${_BUNDLE_NAME_}_} PARENT_SCOPE) # override
endmacro()

function(ADD_CUSTOM_BUILTIN_RESOURCES _TARGET_NAME_ _BUNDLE_NAME_ _BUNDLE_SEARCH_DIRECTORY_ _NAMESPACE_ _OUTPUT_DIRECTORY_)
	if(NOT DEFINED _Python3_EXECUTABLE)
		message(FATAL_ERROR "_Python3_EXECUTABLE must be defined - call find_package(Python3 COMPONENTS Interpreter REQUIRED)")
	endif()

	file(MAKE_DIRECTORY "${_OUTPUT_DIRECTORY_}")

	set(NBL_TEMPLATE_APK_RESOURCES_ARCHIVE_HEADER "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/template/CArchive.h.in")
	set(NBL_BUILTIN_HEADER_GEN_PY "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/builtinHeaderGen.py")
	set(NBL_BUILTIN_DATA_GEN_PY "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/builtinDataGen.py")
	set(NBL_BS_HEADER_FILENAME "builtinResources.h")
	set(NBL_BS_DATA_SOURCE_FILENAME "builtinResourceData.cpp")
	
	string(REPLACE "::" "/" _PATH_PREFIX_ "${_NAMESPACE_}")
	string(REPLACE "::" "_" _GUARD_SUFFIX_ "${_NAMESPACE_}")
	string(REGEX REPLACE "^[0-9]+\." "" _GUARD_SUFFIX_ ${_GUARD_SUFFIX_})
	string(TOUPPER ${_GUARD_SUFFIX_} _GUARD_SUFFIX_)
	string(MAKE_C_IDENTIFIER ${_GUARD_SUFFIX_} _GUARD_SUFFIX_)
	
	set(_ITR_ 0)
	foreach(X IN LISTS _LBR_${_BUNDLE_NAME_}_)
		set(_CURRENT_ITEM_ "${X}")
		string(FIND "${_CURRENT_ITEM_}" "," _FOUND_ REVERSE)
		
		string(REGEX REPLACE ",.*" "" _CURRENT_PATH_ "${_CURRENT_ITEM_}")
		string(REGEX REPLACE ".*," "" _CURRENT_ALIAS_ "${_CURRENT_ITEM_}")
		
		if(EXISTS "${_BUNDLE_SEARCH_DIRECTORY_}/${_CURRENT_PATH_}")
			list(APPEND NBL_DEPENDENCY_FILES "${_BUNDLE_SEARCH_DIRECTORY_}/${_CURRENT_PATH_}")
			file(SIZE "${_BUNDLE_SEARCH_DIRECTORY_}/${_CURRENT_PATH_}" _FILE_SIZE_)
			
			string(APPEND _RESOURCES_INIT_LIST_ "\t\t\t\t\t{\"${_CURRENT_PATH_}\", ${_FILE_SIZE_}, 0xdeadbeefu, ${_ITR_}, nbl::system::IFileArchive::E_ALLOCATOR_TYPE::EAT_NULL},\n") # initializer list
		else()
			message(FATAL_ERROR "!") # TODO: set GENERATED property, therefore we could turn some input into output and list it as builtin resource 
		endif()	
		
		math(EXPR _ITR_ "${_ITR_} + 1")
	endforeach()
	
	configure_file("${NBL_TEMPLATE_APK_RESOURCES_ARCHIVE_HEADER}" "${_OUTPUT_DIRECTORY_}/CArchive.h")
	
	list(APPEND NBL_DEPENDENCY_FILES "${NBL_BUILTIN_HEADER_GEN_PY}")
	list(APPEND NBL_DEPENDENCY_FILES "${NBL_BUILTIN_DATA_GEN_PY}")

	set(NBL_RESOURCES_LIST_FILE "${_OUTPUT_DIRECTORY_}/resources.txt")

	string(REPLACE ";" "," RESOURCES_ARGS "${${_BUNDLE_NAME_}}")
	file(WRITE "${NBL_RESOURCES_LIST_FILE}" "${RESOURCES_ARGS}")

	set(NBL_BUILTIN_RESOURCES_HEADER "${_OUTPUT_DIRECTORY_}/${NBL_BS_HEADER_FILENAME}")
	set(NBL_BUILTIN_RESOURCE_DATA_SOURCE "${_OUTPUT_DIRECTORY_}/${NBL_BS_DATA_SOURCE_FILENAME}")

	add_custom_command(
		OUTPUT "${NBL_BUILTIN_RESOURCES_HEADER}" "${NBL_BUILTIN_RESOURCE_DATA_SOURCE}"
		COMMAND "${_Python3_EXECUTABLE}" "${NBL_BUILTIN_HEADER_GEN_PY}" "${NBL_BUILTIN_RESOURCES_HEADER}" "${_BUNDLE_SEARCH_DIRECTORY_}" "${NBL_RESOURCES_LIST_FILE}" "${_NAMESPACE_}" "${_GUARD_SUFFIX_}"
		COMMAND "${_Python3_EXECUTABLE}" "${NBL_BUILTIN_DATA_GEN_PY}" "${NBL_BUILTIN_RESOURCE_DATA_SOURCE}" "${_BUNDLE_SEARCH_DIRECTORY_}" "${NBL_RESOURCES_LIST_FILE}" "${_NAMESPACE_}" "${NBL_BS_HEADER_FILENAME}"
		COMMENT "Generating built-in resources"
		DEPENDS ${NBL_DEPENDENCY_FILES}
		VERBATIM  
	)
	
	add_library(${_TARGET_NAME_} STATIC
		"${NBL_BUILTIN_RESOURCES_HEADER}"
		"${NBL_BUILTIN_RESOURCE_DATA_SOURCE}"
	)
	
	target_include_directories(${_TARGET_NAME_} PUBLIC "${NBL_ROOT_PATH}/include")
	set_target_properties(${_TARGET_NAME_} PROPERTIES CXX_STANDARD 20)
	
	if(NBL_DYNAMIC_MSVC_RUNTIME)
		set_property(TARGET ${_TARGET_NAME_} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
	else()
		set_property(TARGET ${_TARGET_NAME_} PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
	endif()
	
	list(APPEND _NBL_BUILTIN_RESOURCES_ARCHIVE_APK_SOURCES_ "${_OUTPUT_DIRECTORY_}/CArchive.h")
	set(_NBL_BUILTIN_RESOURCES_ARCHIVE_APK_SOURCES_ ${_NBL_BUILTIN_RESOURCES_ARCHIVE_APK_SOURCES_} PARENT_SCOPE)
	
	list(APPEND _NBL_BUILTIN_RESOURCES_LIBRARIES_ ${_TARGET_NAME_})
	set(_NBL_BUILTIN_RESOURCES_LIBRARIES_ ${_NBL_BUILTIN_RESOURCES_LIBRARIES_} PARENT_SCOPE) # override
endfunction()
