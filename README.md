# swift-mixandmatch-examples

Examples of how to compile swift and objective c together. Both in a single target/module, as well as modules depending on other mixed or single language targets. Going for full `swiftc`, `clang` and `ld` commands to repro what is Apple's official docs in [Mix and Match Overview](https://developer.apple.com/library/content/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html)

## Usage 

There are shellscipts per import/mix case that I identified. Running the shell scripts will write the required files to a `gen/` folder. The first positional argument for the bash script is how it should attempt to compile, options are `manual`, `buck_static` or `buck_shared` for libraries, `buck_build` for binaries.
