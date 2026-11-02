#!/usr/bin/env python3
"""Generate a dependency-free Xcode project with stable identifiers."""
import hashlib, json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
q = lambda value: json.dumps(str(value))
uid = lambda value: hashlib.sha256(value.encode()).hexdigest()[:24].upper()
objects = []
def add(key, body):
    objects.append(f'\t\t{uid(key)} = {{ {body} }};')
    return uid(key)
sources = sorted((root / 'BetterTube').rglob('*.swift'))
resources = [root / 'BetterTube/Assets.xcassets', *sorted((root / 'BetterTube/Web').glob('*')), root / 'BetterTube/PrivacyInfo.xcprivacy']
refs, src_builds, res_builds = [], [], []
for path in sources + resources:
    rel = str(path.relative_to(root / 'BetterTube'))
    typ = 'sourcecode.swift' if path.suffix == '.swift' else 'folder.assetcatalog' if path.suffix == '.xcassets' else 'text.xml' if path.suffix == '.xcprivacy' else 'text'
    ref = add('file:' + rel, f'isa = PBXFileReference; lastKnownFileType = {q(typ)}; path = {q(rel)}; sourceTree = "<group>";')
    build = add('build:' + rel, f'isa = PBXBuildFile; fileRef = {ref};')
    refs.append(ref)
    (src_builds if path in sources else res_builds).append(build)
product = add('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = BetterTube.app; sourceTree = BUILT_PRODUCTS_DIR;')
code = add('code', f'isa = PBXGroup; children = ({",".join(refs)},); path = BetterTube; sourceTree = "<group>";')
products = add('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main = add('main', f'isa = PBXGroup; children = ({code},{products},); sourceTree = "<group>";')
src = add('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(src_builds)},); runOnlyForDeploymentPostprocessing = 0;')
res = add('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(res_builds)},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
project_configs, target_configs = [], []
for name in ['Debug', 'Release']:
    common = {'CLANG_ENABLE_MODULES':'YES','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','SWIFT_STRICT_CONCURRENCY':'targeted','ENABLE_USER_SCRIPT_SANDBOXING':'YES','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if name=='Debug' else ''}
    target = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.glakork.BetterTube','INFOPLIST_FILE':'BetterTube/Info.plist','GENERATE_INFOPLIST_FILE':'NO','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','CODE_SIGN_STYLE':'Automatic','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks','ENABLE_PREVIEWS':'YES'}
    def settings(d): return ' '.join(f'{k} = {q(v)};' for k,v in d.items())
    project_configs.append(add('project-'+name, f'isa = XCBuildConfiguration; buildSettings = {{ {settings(common)} }}; name = {name};'))
    target_configs.append(add('target-'+name, f'isa = XCBuildConfiguration; buildSettings = {{ {settings(target)} }}; name = {name};'))
project_list = add('project-list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target_list = add('target-list', f'isa = XCConfigurationList; buildConfigurations = ({",".join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = add('target', f'isa = PBXNativeTarget; buildConfigurationList = {target_list}; buildPhases = ({src},{frameworks},{res},); buildRules = (); dependencies = (); name = BetterTube; productName = BetterTube; productReference = {product}; productType = "com.apple.product-type.application";')
project = add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1640; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.4; }}; }}; }}; buildConfigurationList = {project_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
(root/'BetterTube.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+'\n\t};\n\trootObject = '+project+';\n}\n')
(root/'BetterTube.xcodeproj/xcshareddata/xcschemes/BetterTube.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="BetterTube.app" BlueprintName="BetterTube" ReferencedContainer="container:BetterTube.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="BetterTube.app" BlueprintName="BetterTube" ReferencedContainer="container:BetterTube.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated BetterTube.xcodeproj')
