#ifndef __I_WINDOW_WAYLAND_H_INCLUDED__
#define __I_WINDOW_WAYLAND_H_INCLUDED__

#include "nbl/system/IWindow.h"

#ifdef _NBL_BUILD_WITH_WAYLAND

#include <wayland-client.h>
#include <wayland-server.h>
#include <wayland-client-protocol.h>

namespace nbl {
namespace system
{

class IWindowWayland : public IWindow
{
protected:
    virtual ~IWindowWayland() = default;

public:
    using IWindow::IWindow;

    using native_handle_t = struct wl_egl_window*;

    virtual native_handle_t getNativeHandle() const = 0;
    virtual struct wl_display* getDisplay() const = 0;
};

}
}

#endif //_NBL_BUILD_WITH_WAYLAND

#endif
