#!/bin/bash
# 基础优化
sed -i 's/remount,ro/remount,rw/g' package/base-files/files/lib/preinit/80_mount_root
sed -i 's/mode_band=.5g./mode_band="2g"/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh || true
sed -i '/ssid_5ghz/d' package/kernel/mac80211/files/lib/wifi/mac80211.sh || true

# 修复策略路由 (IPv4)
for KCFG in target/linux/msm89xx/config-6.12 target/linux/msm89xx/config-default; do
  [ -f "$KCFG" ] || continue
  sed -i '/CONFIG_IP_ADVANCED_ROUTER/d; /CONFIG_IP_MULTIPLE_TABLES/d' "$KCFG"
  echo 'CONFIG_IP_ADVANCED_ROUTER=y' >> "$KCFG"
  echo 'CONFIG_IP_MULTIPLE_TABLES=y' >> "$KCFG"
done

# 固化 OTG 机制 (DTS 补丁)
DTS=target/linux/msm89xx/dts/msm8916-sp970.dtsi
cat >> "$DTS" <<'EODTS'
/ {
    usb_id: usb-id {
        compatible = "linux,extcon-usb-gpio";
        id-gpio = <&tlmm 110 GPIO_ACTIVE_HIGH>;
        pinctrl-names = "default";
        pinctrl-0 = <&usb_id_default>;
    };
};
&tlmm {
    usb_id_default: usb-id-default {
        pins = "gpio110";
        function = "gpio";
        bias-pull-up;
        input-enable;
    };
};
&usb {
    extcon = <&usb_id>;
};
&usb_hs_phy {
    extcon = <&usb_id>;
};
EODTS
