import pathlib, plistlib, sys, shutil, re

app = pathlib.Path(sys.argv[1])
extension = app / 'Contents/PlugIns/WorkBuddyCreditsWidget.appex'
version = pathlib.Path('VERSION').read_text().strip()
build_number = pathlib.Path('BUILD_NUMBER').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not build_number.isdigit():
    raise SystemExit('Invalid VERSION or BUILD_NUMBER')
bundle_id = 'io.github.sanliqingfeng3378-star.workbuddycredits'
base = dict(CFBundleDevelopmentRegion='zh_CN', CFBundleShortVersionString=version, CFBundleVersion=build_number,
            CFBundleSupportedPlatforms=['MacOSX'], LSMinimumSystemVersion='14.0',
            NSAppTransportSecurity={'NSAllowsLocalNetworking': True,
                'NSExceptionDomains': {'127.0.0.1': {'NSExceptionAllowsInsecureHTTPLoads': True}}})
host = dict(base, CFBundleIdentifier=bundle_id, CFBundleName='WorkBuddy 积分',
            CFBundleDisplayName='WorkBuddy 积分', CFBundleExecutable='WorkBuddyCredits', CFBundlePackageType='APPL',
            NSPrincipalClass='NSApplication', NSHighResolutionCapable=True, LSUIElement=True,
            CFBundleURLTypes=[{'CFBundleURLName': 'WorkBuddy Credits', 'CFBundleURLSchemes': ['workbuddycredits']}])
widget = dict(base, CFBundleIdentifier=bundle_id + '.Widget', CFBundleName='WorkBuddy 积分',
              CFBundleDisplayName='WorkBuddy 积分', CFBundleExecutable='WorkBuddyCreditsWidget', CFBundlePackageType='XPC!',
              NSExtension={'NSExtensionPointIdentifier': 'com.apple.widgetkit-extension'})
for bundle, info in [(app, host), (extension, widget)]:
    shutil.copy2('LICENSE', bundle / 'Contents/Resources/LICENSE')
    icon = pathlib.Path('Resources/AppIcon.icns')
    if icon.exists():
        shutil.copy2(icon, bundle / 'Contents/Resources/AppIcon.icns')
        info['CFBundleIconFile'] = 'AppIcon'
    with (bundle / 'Contents/Info.plist').open('wb') as f:
        plistlib.dump(info, f)
