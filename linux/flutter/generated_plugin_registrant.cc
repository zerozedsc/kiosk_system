//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bluetooth_print_plus/bluetooth_print_plus_plugin.h>
#include <file_selector_linux/file_selector_plugin.h>
#include <smart_usb/smart_usb_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) bluetooth_print_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BluetoothPrintPlusPlugin");
  bluetooth_print_plus_plugin_register_with_registrar(bluetooth_print_plus_registrar);
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) smart_usb_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SmartUsbPlugin");
  smart_usb_plugin_register_with_registrar(smart_usb_registrar);
}
