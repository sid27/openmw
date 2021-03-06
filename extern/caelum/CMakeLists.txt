project(Caelum)

IF(MSVC)
    add_definitions("-D_SCL_SECURE_NO_WARNINGS /wd4305 /wd4244" )
ENDIF(MSVC)

ADD_DEFINITIONS(-DCAELUM_STATIC)
INCLUDE_DIRECTORIES( 
    ${CMAKE_HOME_DIRECTORY}/extern/caelum/include 
    ${OGRE_INCLUDE_DIR}/Ogre
    )    

file(GLOB_RECURSE CAELUM_SRC src/*)
file(GLOB_RECURSE CAELUM_HDR include/*)

set(SOURCES ${CAELUM_SRC} ${CAELUM_HDR})
add_library(caelum STATIC ${SOURCES})

#
# Resources
#
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/AtmosphereDepth.png "${OpenMW_BINARY_DIR}/resources/caelum/AtmosphereDepth.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CaelumGroundFog.cg "${OpenMW_BINARY_DIR}/resources/caelum/CaelumGroundFog.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CaelumLayeredClouds.cg "${OpenMW_BINARY_DIR}/resources/caelum/CaelumLayeredClouds.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CaelumPhaseMoon.cg "${OpenMW_BINARY_DIR}/resources/caelum/CaelumPhaseMoon.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CaelumPointStarfield.cg "${OpenMW_BINARY_DIR}/resources/caelum/CaelumPointStarfield.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CaelumSkyDome.cg "${OpenMW_BINARY_DIR}/resources/caelum/CaelumSkyDome.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/CloudCoverLookup.png "${OpenMW_BINARY_DIR}/resources/caelum/CloudCoverLookup.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/DepthComposer.cg "${OpenMW_BINARY_DIR}/resources/caelum/DepthComposer.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/DepthComposer.compositor "${OpenMW_BINARY_DIR}/resources/caelum/DepthComposer.compositor" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/DepthComposer.material "${OpenMW_BINARY_DIR}/resources/caelum/DepthComposer.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/DepthRender.program "${OpenMW_BINARY_DIR}/resources/caelum/DepthRender.program" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/EarthClearSky2.png "${OpenMW_BINARY_DIR}/resources/caelum/EarthClearSky2.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/GroundFog.material "${OpenMW_BINARY_DIR}/resources/caelum/GroundFog.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/GroundFog.program "${OpenMW_BINARY_DIR}/resources/caelum/GroundFog.program" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Haze.program "${OpenMW_BINARY_DIR}/resources/caelum/Haze.program" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/LayeredClouds.material "${OpenMW_BINARY_DIR}/resources/caelum/LayeredClouds.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/MinimalCompositorVP.cg "${OpenMW_BINARY_DIR}/resources/caelum/MinimalCompositorVP.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/MinimalCompositorVP.program "${OpenMW_BINARY_DIR}/resources/caelum/MinimalCompositorVP.program" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/moon.material "${OpenMW_BINARY_DIR}/resources/caelum/moon.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/moon_disc.dds "${OpenMW_BINARY_DIR}/resources/caelum/moon_disc.dds" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/noise1.dds "${OpenMW_BINARY_DIR}/resources/caelum/noise1.dds" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/noise2.dds "${OpenMW_BINARY_DIR}/resources/caelum/noise2.dds" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/noise3.dds "${OpenMW_BINARY_DIR}/resources/caelum/noise3.dds" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/noise4.dds "${OpenMW_BINARY_DIR}/resources/caelum/noise4.dds" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/PointStarfield.material "${OpenMW_BINARY_DIR}/resources/caelum/PointStarfield.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Precipitation.cg "${OpenMW_BINARY_DIR}/resources/caelum/Precipitation.cg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Precipitation.compositor "${OpenMW_BINARY_DIR}/resources/caelum/Precipitation.compositor" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Precipitation.material "${OpenMW_BINARY_DIR}/resources/caelum/Precipitation.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_drizzle.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_drizzle.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_hail.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_hail.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_icecrystals.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_icecrystals.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_icepellets.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_icepellets.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_rain.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_rain.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_smallhail.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_smallhail.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_snow.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_snow.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/precipitation_snowgrains.png "${OpenMW_BINARY_DIR}/resources/caelum/precipitation_snowgrains.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/SkyDome.material "${OpenMW_BINARY_DIR}/resources/caelum/SkyDome.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/sphere.mesh "${OpenMW_BINARY_DIR}/resources/caelum/sphere.mesh" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Starfield.jpg "${OpenMW_BINARY_DIR}/resources/caelum/Starfield.jpg" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Starfield.material "${OpenMW_BINARY_DIR}/resources/caelum/Starfield.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/Sun.material "${OpenMW_BINARY_DIR}/resources/caelum/Sun.material" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/SunGradient.png "${OpenMW_BINARY_DIR}/resources/caelum/SunGradient.png" COPYONLY)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/resources/sun_disc.png "${OpenMW_BINARY_DIR}/resources/caelum/sun_disc.png" COPYONLY)
