PLUGIN_ID := org.kde.plasma.xmbwaves
QSB := $(shell command -v qsb-qt6 || command -v /usr/lib64/qt6/bin/qsb || command -v /usr/lib/qt6/bin/qsb || command -v qsb)
KPACKAGETOOL := kpackagetool6

VERT_SRC := shaders/xmb.vert
VERT_OUT := package/contents/ui/shaders/xmb.vert.qsb
FRAG_SRC := shaders/xmb.frag
FRAG_OUT := package/contents/ui/shaders/xmb.frag.qsb

.PHONY: all shader install uninstall clean

all: shader

shader: $(VERT_OUT) $(FRAG_OUT)

$(VERT_OUT): $(VERT_SRC)
	@mkdir -p $(dir $(VERT_OUT))
	$(QSB) --qt6 -b -o $(VERT_OUT) $(VERT_SRC)

$(FRAG_OUT): $(FRAG_SRC)
	@mkdir -p $(dir $(FRAG_OUT))
	$(QSB) --qt6 -o $(FRAG_OUT) $(FRAG_SRC)

install: shader
	@if $(KPACKAGETOOL) --type Plasma/Wallpaper --show $(PLUGIN_ID) >/dev/null 2>&1; then \
		$(KPACKAGETOOL) --type Plasma/Wallpaper --upgrade package; \
	else \
		$(KPACKAGETOOL) --type Plasma/Wallpaper --install package; \
	fi
	rm -rf "$${XDG_CACHE_HOME:-$$HOME/.cache}/plasmashell/qmlcache"
	systemctl --user restart plasma-plasmashell.service 2>/dev/null || true

uninstall:
	$(KPACKAGETOOL) --type Plasma/Wallpaper --remove $(PLUGIN_ID)

clean:
	rm -f $(VERT_OUT) $(FRAG_OUT)
