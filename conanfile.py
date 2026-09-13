from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeDeps, cmake_layout

class NetClientConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeToolchain", "CMakeDeps"

    def requirements(self):
        # ESP32 no pasa por Conan, así que ni siquiera necesitas
        # excluirlo aquí -- simplemente no invocarás conan install con ese perfil
        self.requires("openssl/3.2.1")

    def layout(self):
        cmake_layout(self)

# conan install . -pr:h=android_armv8 -pr:b=default --build=missing -of=build/android