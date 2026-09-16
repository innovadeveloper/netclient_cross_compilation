from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeDeps, cmake_layout

class sampleConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeToolchain", "CMakeDeps"

    def requirements(self):
        self.requires("libcurl/8.5.0")
        self.requires("paho-mqtt-c/1.3.16")


    def layout(self):
        cmake_layout(self)
