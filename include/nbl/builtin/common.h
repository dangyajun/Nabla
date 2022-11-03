// Copyright (C) 2018-2020 - DevSH Graphics Programming Sp. z O.O.
// This file is part of the "Nabla Engine".
// For conditions of distribution and use, see copyright notice in nabla.h

#ifndef _NBL_BUILTIN_COMMON_H_INCLUDED_
#define _NBL_BUILTIN_COMMON_H_INCLUDED_

#include "BuildConfigOptions.h"

#include <string>

#include "nbl/core/string/StringLiteral.h"

namespace nbl::builtin
{

// if you attempt to use this without `NBL_EMBED_BUILTIN_RESOURCES_` CMake option, you will get loads of undefined references
template<nbl::core::StringLiteral Path>
const std::pair<const uint8_t*,size_t> get_resource();

// if you attempt to use this without `NBL_EMBED_BUILTIN_RESOURCES_` CMake option, this will always return `{nullptr,0ull}`
std::pair<const uint8_t*,size_t> get_resource_runtime(const std::string&);


#ifndef _NBL_EMBED_BUILTIN_RESOURCES_
#define _NBL_BUILTIN_PATH_AVAILABLE
constexpr std::string_view getBuiltinResourcesDirectoryPath()
{
    std::string_view retval = __FILE__;
    retval.remove_suffix(std::string_view("common.h").size());
    return retval;
}
#endif

}
#endif
