THEOS = $(HOME)/Software/theos
THEOS_DEVICE_IP = 10.1.192.200

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ThingsforVelox
ThingsforVelox_FILES = ThingsforVeloxFolderView.mm
ThingsforVelox_INSTALL_PATH = /Library/Velox/Plugins/
ThingsforVelox_FRAMEWORKS = Foundation UIKit 
ThingsforVelox_LDFLAGS = -lsqlite3

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard"
