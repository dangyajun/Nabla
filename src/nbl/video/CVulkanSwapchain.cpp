#include "nbl/video/CVulkanSwapchain.h"

#include "nbl/video/CVulkanLogicalDevice.h"
#include "nbl/video/CVulkanImage.h"
#include "nbl/video/CVulkanConnection.h"

namespace nbl::video
{

core::smart_refctd_ptr<CVulkanSwapchain> CVulkanSwapchain::create(core::smart_refctd_ptr<const ILogicalDevice>&& logicalDevice, ISwapchain::SCreationParams&& params, core::smart_refctd_ptr<CVulkanSwapchain>&& oldSwapchain)
{ 
    if (!logicalDevice || logicalDevice->getAPIType()!=EAT_VULKAN || logicalDevice->getEnabledFeatures().swapchainMode==ESM_NONE)
        return nullptr;
    if (!params.surface)
        return nullptr;

    // now check if any queue family of the physical device supports this surface
    {
        auto physDev = logicalDevice->getPhysicalDevice();

        bool noSupport = true;
        for (auto familyIx=0u; familyIx<ILogicalDevice::MaxQueueFamilies; familyIx++)
        if (logicalDevice->getQueueCount(familyIx) && params.surface->isSupportedForPhysicalDevice(physDev,familyIx))
        {
            noSupport = false;
            break;
        }
        if (noSupport)
            return nullptr;
    }

    auto device = core::smart_refctd_ptr_static_cast<const CVulkanLogicalDevice>(logicalDevice);
    const VkSurfaceKHR vk_surface = static_cast<const ISurfaceVulkan*>(params.surface.get())->getInternalObject();

    // get present mode
    VkPresentModeKHR vkPresentMode;
    switch (params.sharedParams.presentMode.value)
    {
        case ISurface::E_PRESENT_MODE::EPM_IMMEDIATE:
            vkPresentMode = VK_PRESENT_MODE_IMMEDIATE_KHR;
            break;
        case ISurface::E_PRESENT_MODE::EPM_MAILBOX:
            vkPresentMode = VK_PRESENT_MODE_MAILBOX_KHR;
            break;
        case ISurface::E_PRESENT_MODE::EPM_FIFO:
            vkPresentMode = VK_PRESENT_MODE_FIFO_KHR;
            break;
        case ISurface::E_PRESENT_MODE::EPM_FIFO_RELAXED:
            vkPresentMode = VK_PRESENT_MODE_FIFO_RELAXED_KHR;
            break;
        default:
            return nullptr;
    }

    auto& vk = device->getFunctionTable()->vk;
    const auto vk_device = device->getInternalObject();

    VkSwapchainKHR vk_swapchain;
    {
        //! fill format list for mutable formats
        VkImageFormatListCreateInfo vk_formatListStruct = { VK_STRUCTURE_TYPE_IMAGE_FORMAT_LIST_CREATE_INFO, nullptr };
        vk_formatListStruct.viewFormatCount = 0u;
        std::array<VkFormat,asset::E_FORMAT::EF_COUNT> vk_formatList;

        VkSwapchainCreateInfoKHR vk_createInfo = { VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, &vk_formatListStruct };
        // if only there existed a nice iterator that would let me iterate over set bits 64 faster
        const auto& viewFormats = params.sharedParams.viewFormats;
        if (viewFormats.any())
        {
            // structure with a viewFormatCount greater than zero and pViewFormats must have an element equal to imageFormat
            // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VkSwapchainCreateInfoKHR.html#VUID-VkSwapchainCreateInfoKHR-flags-03168
            if (!viewFormats.test(params.surfaceFormat.format))
                return nullptr;

            for (auto fmt=0; fmt<vk_formatList.size(); fmt++)
            if (viewFormats.test(fmt))
            {
                const auto format = static_cast<asset::E_FORMAT>(fmt);
                // https://registry.khronos.org/vulkan/specs/1.3-extensions/man/html/VkSwapchainCreateInfoKHR.html#VUID-VkSwapchainCreateInfoKHR-pNext-04099
                if (asset::getFormatClass(format)!=asset::getFormatClass(params.surfaceFormat.format))
                    return nullptr;
                vk_formatList[vk_formatListStruct.viewFormatCount++] = getVkFormatFromFormat(format);
            }

            // just deduce the mutable flag, cause we're so constrained by spec, it dictates we must list all formats if we're doing mutable
            if (vk_formatListStruct.viewFormatCount>1)
                vk_createInfo.flags |= VK_SWAPCHAIN_CREATE_MUTABLE_FORMAT_BIT_KHR;
        }
        vk_formatListStruct.pViewFormats = vk_formatList.data();

        std::array<uint32_t, ILogicalDevice::MaxQueueFamilies> queueFamilyIndices;
        std::copy(params.queueFamilyIndices.begin(),params.queueFamilyIndices.end(),queueFamilyIndices.data());
        vk_createInfo.surface = vk_surface;
        vk_createInfo.minImageCount = params.sharedParams.minImageCount;
        vk_createInfo.imageFormat = getVkFormatFromFormat(params.surfaceFormat.format);
        vk_createInfo.imageColorSpace = getVkColorSpaceKHRFromColorSpace(params.surfaceFormat.colorSpace);
        vk_createInfo.imageExtent = {params.sharedParams.width,params.sharedParams.height};
        vk_createInfo.imageArrayLayers = params.sharedParams.arrayLayers;
        vk_createInfo.imageUsage = getVkImageUsageFlagsFromImageUsageFlags(params.sharedParams.imageUsage,asset::isDepthOrStencilFormat(params.surfaceFormat.format));
        vk_createInfo.imageSharingMode = params.isConcurrentSharing() ? VK_SHARING_MODE_CONCURRENT:VK_SHARING_MODE_EXCLUSIVE;
        vk_createInfo.queueFamilyIndexCount = queueFamilyIndices.size();
        vk_createInfo.pQueueFamilyIndices = queueFamilyIndices.data();
        vk_createInfo.preTransform = static_cast<VkSurfaceTransformFlagBitsKHR>(params.sharedParams.preTransform.value);
        vk_createInfo.compositeAlpha = static_cast<VkCompositeAlphaFlagBitsKHR>(params.sharedParams.compositeAlpha.value);
        vk_createInfo.presentMode = vkPresentMode;
        vk_createInfo.clipped = VK_FALSE;
        if (oldSwapchain)
        {
            assert(oldSwapchain->wasCreatedBy(device.get()));
            vk_createInfo.oldSwapchain = oldSwapchain->getInternalObject();
        }
        else
            vk_createInfo.oldSwapchain = VK_NULL_HANDLE;

        if (vk.vkCreateSwapchainKHR(vk_device,&vk_createInfo,nullptr,&vk_swapchain)!=VK_SUCCESS)
            return nullptr;
    }

    uint32_t imageCount;
    VkResult retval = vk.vkGetSwapchainImagesKHR(vk_device,vk_swapchain,&imageCount,nullptr);
    if (retval!=VK_SUCCESS)
        return nullptr;

    //
    VkSemaphore adaptorSemaphores[2*ISwapchain::MaxImages];
    {
        VkSemaphoreCreateInfo info = {VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,nullptr};
        info.flags = 0u;
        for (auto i=0u; i<2*imageCount; i++)
        if (vk.vkCreateSemaphore(vk_device,&info,nullptr,adaptorSemaphores+i)!=VK_SUCCESS)
        {
            // handle successful allocs before failure
            for (auto j=0u; j<i; j++)
                vk.vkDestroySemaphore(vk_device,adaptorSemaphores[j],nullptr);
            return nullptr;
        }
    }
    VkFence prePresentFences[ISwapchain::MaxImages];
    {
        VkFenceCreateInfo info = {VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,nullptr};
        info.flags = VK_FENCE_CREATE_SIGNALED_BIT; // makes life easier on the very first acquire and in the destructor
        for (auto i=0u; i<imageCount; i++)
        if (vk.vkCreateFence(vk_device,&info,nullptr,prePresentFences+i)!=VK_SUCCESS)
        {
            // handle successful allocs before failure
            for (auto j=0u; j<ISwapchain::MaxImages; j++)
                vk.vkDestroySemaphore(vk_device,adaptorSemaphores[j],nullptr);
            for (auto j=0u; j<i; j++)
                vk.vkDestroyFence(vk_device,prePresentFences[j],nullptr);
            return nullptr;
        }
    }

    return core::smart_refctd_ptr<CVulkanSwapchain>(new CVulkanSwapchain(std::move(device),std::move(params),imageCount,std::move(oldSwapchain),vk_swapchain,adaptorSemaphores,prePresentFences),core::dont_grab);
}

CVulkanSwapchain::CVulkanSwapchain(
    core::smart_refctd_ptr<const ILogicalDevice>&& logicalDevice,
    SCreationParams&& params,
    const uint32_t imageCount,
    core::smart_refctd_ptr<CVulkanSwapchain>&& oldSwapchain,
    const VkSwapchainKHR swapchain,
    const VkSemaphore* const _adaptorSemaphores,
    const VkFence* const _prePresentFences
) : ISwapchain(std::move(logicalDevice),std::move(params),imageCount,std::move(oldSwapchain)),
    m_imgMemRequirements{.size=0,.memoryTypeBits=0x0u,.alignmentLog2=63,.prefersDedicatedAllocation=true,.requiresDedicatedAllocation=true}, m_vkSwapchainKHR(swapchain)
{
    // we've got it from here!
    if (m_oldSwapchain)
        static_cast<CVulkanSwapchain*>(m_oldSwapchain.get())->m_needToWaitIdle = false;

    {
        const CVulkanLogicalDevice* vulkanDevice = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());
        uint32_t dummy = imageCount;
        auto retval = vulkanDevice->getFunctionTable()->vk.vkGetSwapchainImagesKHR(vulkanDevice->getInternalObject(),m_vkSwapchainKHR,&dummy,m_images);
        assert(retval==VK_SUCCESS && dummy==getImageCount());
    }

    std::copy_n(_adaptorSemaphores,imageCount,m_acquireAdaptorSemaphores);
    std::copy_n(_prePresentFences,imageCount,m_prePresentFences);
    std::copy_n(_adaptorSemaphores+imageCount,imageCount,m_presentAdaptorSemaphores);
}

CVulkanSwapchain::~CVulkanSwapchain()
{
    // I'd rather have the oldest swapchain cleanup first
    m_oldSwapchain = nullptr;

    const CVulkanLogicalDevice* vulkanDevice = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());
    auto& vk = vulkanDevice->getFunctionTable()->vk;
    const auto vk_device = vulkanDevice->getInternalObject();
    if (m_needToWaitIdle)
        vk.vkDeviceWaitIdle(vk_device);

    while (true) // if you find yourself spinning here forever, it might be because you didn't present an already acquired image
    if (vk.vkWaitForFences(vk_device,getImageCount(),m_prePresentFences,true,~0ull)!=VK_TIMEOUT)
        break;
    for (auto i=0; i<getImageCount(); i++)
        vk.vkDestroyFence(vk_device,m_prePresentFences[i],nullptr);

    for (auto i=0u; i<getImageCount(); i++)
    {
        vk.vkDestroySemaphore(vk_device,m_acquireAdaptorSemaphores[i],nullptr);
        vk.vkDestroySemaphore(vk_device,m_presentAdaptorSemaphores[i],nullptr);
    }

    vk.vkDestroySwapchainKHR(vk_device,m_vkSwapchainKHR,nullptr);
}

bool CVulkanSwapchain::unacquired(const uint8_t imageIndex) const
{
    const CVulkanLogicalDevice* vulkanDevice = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());
    // Only lets us know if we're after a successful CPU call to acquire an image, and before the GPU finishes all work blocking the present!
    return vulkanDevice->getFunctionTable()->vk.vkGetFenceStatus(vulkanDevice->getInternalObject(),m_prePresentFences[imageIndex])!=VK_NOT_READY;
}

auto CVulkanSwapchain::acquireNextImage_impl(const SAcquireInfo& info, uint32_t* const out_imgIx) -> ACQUIRE_IMAGE_RESULT
{
    const CVulkanLogicalDevice* vulkanDevice = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());

    auto* vulkanQueue = IBackendObject::device_compatibility_cast<CVulkanQueue*>(info.queue,vulkanDevice);
    if (!vulkanQueue)
        return ACQUIRE_IMAGE_RESULT::_ERROR;
    for (const auto& waitInfo : info.signalSemaphores)
    if (!IBackendObject::device_compatibility_cast<CVulkanSemaphore*>(waitInfo.semaphore,vulkanDevice))
        return ACQUIRE_IMAGE_RESULT::_ERROR;

    const VkSemaphoreSubmitInfo adaptorInfo = {
        .sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
        .pNext = nullptr,
        .semaphore = m_acquireAdaptorSemaphores[getAcquireCount()%getImageCount()],
        .value = 0, // value is ignored because the adaptors are binary
        .stageMask = VK_PIPELINE_STAGE_2_NONE,
        .deviceIndex = 0u // TODO: later obtain device index from swapchain
    };

    bool suboptimal = false;

    auto& vk = vulkanDevice->getFunctionTable()->vk;
    const VkDevice vk_device = vulkanDevice->getInternalObject();
    {
        VkAcquireNextImageInfoKHR acquire = {VK_STRUCTURE_TYPE_ACQUIRE_NEXT_IMAGE_INFO_KHR,nullptr};
        acquire.swapchain = m_vkSwapchainKHR;
        acquire.timeout = info.timeout;
        acquire.semaphore = adaptorInfo.semaphore;
        acquire.fence = VK_NULL_HANDLE;
        acquire.deviceMask = 0x1u<<adaptorInfo.deviceIndex;
        switch (vk.vkAcquireNextImage2KHR(vk_device,&acquire,out_imgIx))
        {
            case VK_SUCCESS:
                break;
            case VK_TIMEOUT:
                return ACQUIRE_IMAGE_RESULT::TIMEOUT;
            case VK_NOT_READY:
                return ACQUIRE_IMAGE_RESULT::NOT_READY;
            case VK_SUBOPTIMAL_KHR:
                suboptimal = true;
                break;
            default:
                return ACQUIRE_IMAGE_RESULT::_ERROR;
        }
    }
    const auto imgIx = *out_imgIx;
    
    // The previous present on the image MUST have had finished
    assert(unacquired(imgIx));
    // Now put the fence into UNSIGNALLED state where it will stay until "just before" the present
    {
        const bool result = vk.vkResetFences(vk_device,1,m_prePresentFences+imgIx)==VK_SUCCESS;
        // If this goes wrong, we are lost without KHR_swapchain_maintenance1 because there's no way to release acquired images without presenting them!
        assert(result);
    }

    core::vector<VkSemaphoreSubmitInfo> signalInfos(info.signalSemaphores.size(),{VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,nullptr});
    for (auto i=0u; i<info.signalSemaphores.size(); i++)
    {
        signalInfos[i].semaphore = static_cast<CVulkanSemaphore*>(info.signalSemaphores[i].semaphore)->getInternalObject();
        signalInfos[i].stageMask = getVkPipelineStageFlagsFromPipelineStageFlags(info.signalSemaphores[i].stageMask);
        signalInfos[i].value = info.signalSemaphores[i].value;
        signalInfos[i].deviceIndex = 0u;
    }

    {
        VkSubmitInfo2 submit = {VK_STRUCTURE_TYPE_SUBMIT_INFO_2,nullptr};
        submit.waitSemaphoreInfoCount = 1u;
        submit.pWaitSemaphoreInfos = &adaptorInfo;
        submit.commandBufferInfoCount = 0u;
        submit.signalSemaphoreInfoCount = info.signalSemaphores.size();
        submit.pSignalSemaphoreInfos = signalInfos.data();
        const bool result = vk.vkQueueSubmit2(vulkanQueue->getInternalObject(),1u,&submit,VK_NULL_HANDLE)==VK_SUCCESS;
        // If this goes wrong, we are lost without KHR_swapchain_maintenance1 because there's no way to release acquired images without presenting them!
        assert(result);
    }
    return suboptimal ? ACQUIRE_IMAGE_RESULT::SUBOPTIMAL:ACQUIRE_IMAGE_RESULT::SUCCESS;
}

auto CVulkanSwapchain::present_impl(const SPresentInfo& info) -> PRESENT_RESULT
{    
    const CVulkanLogicalDevice* vulkanDevice = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());
    auto vulkanQueue = IBackendObject::device_compatibility_cast<CVulkanQueue*>(info.queue,vulkanDevice);
    if (!vulkanQueue)
        return PRESENT_RESULT::FATAL_ERROR;

    auto& vk = vulkanDevice->getFunctionTable()->vk;
    const auto vk_device = vulkanDevice->getInternalObject();

    // We make the present wait on an empty submit so we can signal our "not-acquired" fence
    VkSemaphoreSubmitInfo adaptorInfo = {
        .sType = VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,
        .pNext = nullptr,
        .semaphore =  m_presentAdaptorSemaphores[info.imgIndex],
        .value = 0,// value is ignored because the adaptors are binary
        .stageMask = VK_PIPELINE_STAGE_2_NONE,
        .deviceIndex = 0u // TODO: later
    };

    // Optionally the submit ties timeline semaphore waits with itself
    core::vector<VkSemaphoreSubmitInfo> waitInfos(info.waitSemaphores.size(),{VK_STRUCTURE_TYPE_SEMAPHORE_SUBMIT_INFO,nullptr});
    for (auto i=0u; i<info.waitSemaphores.size(); i++)
    {
        auto sema = IBackendObject::device_compatibility_cast<CVulkanSemaphore*>(info.waitSemaphores[i].semaphore,vulkanDevice);
        if (!sema)
            return PRESENT_RESULT::FATAL_ERROR;
        waitInfos[i].semaphore = sema->getInternalObject();
        waitInfos[i].stageMask = getVkPipelineStageFlagsFromPipelineStageFlags(info.waitSemaphores[i].stageMask);
        waitInfos[i].value = info.waitSemaphores[i].value;
        waitInfos[i].deviceIndex = 0u;
    }

    // Perform the empty submit
    {
        VkSubmitInfo2 submit = {VK_STRUCTURE_TYPE_SUBMIT_INFO_2,nullptr};
        submit.waitSemaphoreInfoCount = info.waitSemaphores.size();
        submit.pWaitSemaphoreInfos = waitInfos.data();
        submit.commandBufferInfoCount = 0u;
        submit.signalSemaphoreInfoCount = 1u;
        submit.pSignalSemaphoreInfos = &adaptorInfo;
        if (vk.vkQueueSubmit2(vulkanQueue->getInternalObject(),1u,&submit,m_prePresentFences[info.imgIndex])!=VK_SUCCESS)
        {
            // need to recreate because can't signal a Fence from the Host
            vk.vkDestroyFence(vk_device,m_prePresentFences[info.imgIndex],nullptr);
            VkFenceCreateInfo createInfo = {VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,nullptr};
            createInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT; // makes life easier on the very first acquire and in the destructor
            vk.vkCreateFence(vk_device,&createInfo,nullptr,m_prePresentFences+info.imgIndex);
            return PRESENT_RESULT::FATAL_ERROR;
        }
    }

    VkPresentInfoKHR presentInfo = {VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,nullptr};
    presentInfo.waitSemaphoreCount = 1u;
    presentInfo.pWaitSemaphores = &adaptorInfo.semaphore;
    presentInfo.swapchainCount = 1u;
    presentInfo.pSwapchains = &m_vkSwapchainKHR;
    presentInfo.pImageIndices = &info.imgIndex;

    VkResult retval = vk.vkQueuePresentKHR(vulkanQueue->getInternalObject(),&presentInfo);
    switch (retval)
    {
        case VK_SUCCESS:
            break;
        case VK_SUBOPTIMAL_KHR:
            return PRESENT_RESULT::SUBOPTIMAL;
        case VK_ERROR_OUT_OF_HOST_MEMORY:
        case VK_ERROR_OUT_OF_DEVICE_MEMORY:
            // as per the spec, only these "hard" errors don't result in the binary semaphore getting waited on
            vk.vkQueueWaitIdle(vulkanQueue->getInternalObject());
            vk.vkDestroySemaphore(vk_device,adaptorInfo.semaphore,nullptr);
            {
                VkSemaphoreCreateInfo createInfo = {VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,nullptr};
                createInfo.flags = 0u;
                vk.vkCreateSemaphore(vk_device,&createInfo,nullptr,m_presentAdaptorSemaphores+info.imgIndex);
            }
            [[fallthrough]];
        case VK_ERROR_DEVICE_LOST:
            return PRESENT_RESULT::_ERROR;
        default:
            return PRESENT_RESULT::OUT_OF_DATE;
    }
    return PRESENT_RESULT::SUCCESS;
}

core::smart_refctd_ptr<ISwapchain> CVulkanSwapchain::recreate_impl(SSharedCreationParams&& params)
{
    SCreationParams fullParams = {
        .surface = core::smart_refctd_ptr(getCreationParameters().surface),
        .surfaceFormat = getCreationParameters().surfaceFormat,
        .sharedParams = std::move(params),
        .queueFamilyIndices = getCreationParameters().queueFamilyIndices
    };
    return create(core::smart_refctd_ptr<const ILogicalDevice>(getOriginDevice()),std::move(fullParams),core::smart_refctd_ptr<CVulkanSwapchain>(this));
}

core::smart_refctd_ptr<IGPUImage> CVulkanSwapchain::createImage(const uint32_t imageIndex)
{
    if (!setImageExists(imageIndex))
        return nullptr;

    // TODO figure out image create path
    // https://github.com/KhronosGroup/Vulkan-ValidationLayers/issues/4343
    // for (uint32_t i = 0; i < imageCount; i++)
    // {
    //     VkImageSwapchainCreateInfoKHR vk_imgSwapchainCreateInfo = { VK_STRUCTURE_TYPE_IMAGE_SWAPCHAIN_CREATE_INFO_KHR };
    //     vk_imgSwapchainCreateInfo.pNext = nullptr;
    //     vk_imgSwapchainCreateInfo.swapchain = vk_swapchain;
    // 
    //     // https://registry.khronos.org/vulkan/specs/1.3-extensions/html/vkspec.html#swapchain-wsi-image-create-info
    //     VkImageCreateInfo vk_imgCreateInfo = { VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO };
    //     vk_imgCreateInfo.pNext = &vk_imgSwapchainCreateInfo; // there are a lot of extensions
    //     vk_imgCreateInfo.flags = static_cast<VkImageCreateFlags>(0);
    //     vk_imgCreateInfo.imageType = static_cast<VkImageType>(VK_IMAGE_TYPE_2D);
    //     vk_imgCreateInfo.format = getVkFormatFromFormat(params.surfaceFormat.format);
    //     vk_imgCreateInfo.extent = { params.width, params.height, 1 };
    //     vk_imgCreateInfo.mipLevels = 1;
    //     vk_imgCreateInfo.arrayLayers = params.arrayLayers;
    //     vk_imgCreateInfo.samples = VK_SAMPLE_COUNT_1_BIT;
    //     vk_imgCreateInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
    //     vk_imgCreateInfo.usage = static_cast<VkImageUsageFlags>(params.imageUsage.value);
    //     vk_imgCreateInfo.sharingMode = static_cast<VkSharingMode>(params.imageSharingMode);
    //     vk_imgCreateInfo.queueFamilyIndexCount = params.queueFamilyIndexCount;
    //     vk_imgCreateInfo.pQueueFamilyIndices = params.queueFamilyIndices;
    //     vk_imgCreateInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    // 
    //     device->getFunctionTable()->vk.vkCreateImage(device->getInternalObject(), &vk_imgCreateInfo, nullptr, &vk_images[i]);
    // 
    //     VkBindImageMemorySwapchainInfoKHR vk_bindImgMemorySwapchainInfo = { VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_SWAPCHAIN_INFO_KHR };
    //     vk_bindImgMemorySwapchainInfo.pNext = nullptr;
    //     vk_bindImgMemorySwapchainInfo.imageIndex = i;
    //     vk_bindImgMemorySwapchainInfo.swapchain = vk_swapchain;
    // 
    //     VkBindImageMemoryInfo vk_bindImgMemoryInfo = { VK_STRUCTURE_TYPE_BIND_IMAGE_MEMORY_INFO };
    //     vk_bindImgMemoryInfo.pNext = &vk_bindImgMemorySwapchainInfo;
    //     vk_bindImgMemoryInfo.image = vk_images[i];
    //     vk_bindImgMemoryInfo.memory = nullptr;
    // 
    //     device->getFunctionTable()->vk.vkBindImageMemory2(device->getInternalObject(), 1, &vk_bindImgMemoryInfo);
    //     assert(vk_images[i]);
    // }

    auto device = static_cast<const CVulkanLogicalDevice*>(getOriginDevice());
    
    std::array<uint32_t,ILogicalDevice::MaxQueueFamilies> queueFamilyIndices;
    std::copy(getCreationParameters().queueFamilyIndices.begin(),getCreationParameters().queueFamilyIndices.end(),queueFamilyIndices.data());
    IGPUImage::SCreationParams creationParams = {};
    static_cast<asset::IImage::SCreationParams&>(creationParams) = getImageCreationParams();
    creationParams.preDestroyCleanup = std::make_unique<CCleanupSwapchainReference>(core::smart_refctd_ptr<ISwapchain>(this), imageIndex);
    creationParams.postDestroyCleanup = nullptr;
    creationParams.queueFamilyIndexCount = queueFamilyIndices.size();
    creationParams.skipHandleDestroy = true;
    creationParams.queueFamilyIndices = queueFamilyIndices.data();
    creationParams.tiling = IGPUImage::TILING::OPTIMAL;
    creationParams.preinitialized = false;

    return core::make_smart_refctd_ptr<CVulkanImage>(device,std::move(creationParams),m_imgMemRequirements,m_images[imageIndex]);
}

void CVulkanSwapchain::setObjectDebugName(const char* label) const
{
    IBackendObject::setObjectDebugName(label);

    if (!vkSetDebugUtilsObjectNameEXT)
        return;

    VkDebugUtilsObjectNameInfoEXT nameInfo = {VK_STRUCTURE_TYPE_DEBUG_UTILS_OBJECT_NAME_INFO_EXT,nullptr};
    nameInfo.objectType = VK_OBJECT_TYPE_SWAPCHAIN_KHR;
    nameInfo.objectHandle = reinterpret_cast<uint64_t>(getInternalObject());
    nameInfo.pObjectName = getObjectDebugName();
    vkSetDebugUtilsObjectNameEXT(static_cast<const CVulkanLogicalDevice*>(getOriginDevice())->getInternalObject(),&nameInfo);
}

}
