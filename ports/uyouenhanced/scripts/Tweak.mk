ARCHS = arm64
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = uYouEnhanced YouTubeDislikesReturn
COMMON_SOURCES = Sources/UYTOffline.m Sources/UYTDirectFormats.m Sources/UYTSponsor.m Sources/UYTSponsorTimeline.m Sources/UYTMenuHooks.xm Sources/UYTSponsorHooks.xm Sources/UYTPlayerControls.xm
ifeq ($(PORT_PROFILE),rootful)
uYouEnhanced_FILES = $(COMMON_SOURCES) Sources/UYTLegacyEntry.xm
else
uYouEnhanced_FILES = $(filter-out Sources/UYTLegacyEntry.xm,$(wildcard Sources/*.xm) $(wildcard Sources/*.x) $(wildcard Sources/*.m))
endif
uYouEnhanced_FRAMEWORKS = UIKit Foundation AVFoundation AVKit Photos Accelerate CoreMotion GameController VideoToolbox Security
uYouEnhanced_LIBRARIES = bz2 c++ iconv z
uYouEnhanced_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-but-set-variable -DTWEAK_VERSION=\"$(PORT_VERSION)\"
RYD = Tweaks/Return-YouTube-Dislikes
YouTubeDislikesReturn_FILES = $(RYD)/Settings.x $(RYD)/TweakSettings.x $(RYD)/API.x $(RYD)/Vote.x $(RYD)/Tweak.x
YouTubeDislikesReturn_FRAMEWORKS = UIKit Foundation Security
YouTubeDislikesReturn_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -DAPI_URL=\"https://returnyoutubedislikeapi.com\" -DTWEAK_NAME=\"Return\ YouTube\ Dislike\"
ADDITIONAL_CFLAGS = -ITweaks -ITweaks/RemoteLog -ISources -fmodules-cache-path=$(THEOS_PROJECT_DIR)/../clang-cache
ifeq ($(PORT_PROFILE),rootful)
ADDITIONAL_CFLAGS += -Werror=unguarded-availability
# Logos emits Objective-C++; this port uses no C++ standard-library APIs.
ADDITIONAL_CFLAGS += -D_LIBCPP_DISABLE_AVAILABILITY -Wno-error=cpp
endif
ADDITIONAL_LDFLAGS = -Wl,-no_fixup_chains -Wl,-no_adhoc_codesign
include $(THEOS_MAKE_PATH)/tweak.mk
