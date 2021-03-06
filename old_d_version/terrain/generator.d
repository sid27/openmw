/*
  OpenMW - The completely unofficial reimplementation of Morrowind
  Copyright (C) 2008-2009  Nicolay Korslund
  Email: < korslund@gmail.com >
  WWW: http://openmw.snaptoad.com/

  This file (generator.d) is part of the OpenMW package.

  OpenMW is distributed as free software: you can redistribute it
  and/or modify it under the terms of the GNU General Public License
  version 3, as published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  version 3 along with this program. If not, see
  http://www.gnu.org/licenses/ .

*/

// This module is responsible for generating the cache files.
module terrain.generator;

import std.stdio;
import std.string;
import std.math2;
import std.c.string;

import terrain.cachewriter;
import terrain.archive;
import terrain.esmland;
import terrain.terrain;
import terrain.bindings;

import util.cachefile;

import monster.util.aa;
import monster.util.string;
import monster.vm.dbg;

int mCount;

// Texture sizes for the various levels. For the most detailed level
// (level 1), this give the size of the alpha splatting textures rather
// than a final texture.
int[] texSizes;

CacheWriter cache;

void generate(char[] filename)
{
  makePath(cacheDir);

  cache.openFile(filename);

  // Find the maxiumum distance from (0,0) in any direction
  int max = mwland.getMaxCoord();

  // Round up to nearest power of 2
  int depth=1;
  while(max)
    {
      max >>= 1;
      depth++;
      assert(depth <= 8);
    }
  max = 1 << depth-1;

  // We already know the answers
  assert(max == 32);
  assert(depth == 6);

  // Set the texture sizes. TODO: These should be config options,
  // perhaps - or maybe a result of some higher-level detail setting.
  texSizes.length = depth+1;
  texSizes[6] = 1024;
  texSizes[5] = 512;
  texSizes[4] = 256;
  texSizes[3] = 256;
  texSizes[2] = 512;
  texSizes[1] = 64;

  // Set some general parameters for the runtime
  cache.setParams(depth+1, texSizes[1]);

  // Create some common data first
  writefln("Generating common data");
  genDefaults();
  genIndexData();

  writefln("Generating quad data");
  GenLevelResult gen;

  // Start at one level above the top, but don't generate data for it
  genLevel(depth+1, -max, -max, gen, false);

  writefln("Writing index file");
  cache.finish();
  writefln("Pregeneration done. Results written to ", filename);
}

struct GenLevelResult
{
  QuadHolder quad;

  bool hasMesh;
  bool isAlpha;

  int width;

  ubyte[] data;

  void allocImage(int _width)
  {
    assert(isEmpty());

    width = _width;
    data.length = width*width*3;
    quad.meshes.length = 1;

    assert(!hasAlpha());
  }

  void allocAlphas(int _width, int texNum)
  {
    assert(isEmpty() || hasMesh);

    width = _width;
    data.length = width*width*texNum;
    isAlpha = true;

    // Set up the alpha images. TODO: We have to split these over
    // several meshes, but for now pretend that we're using only
    // one.
    assert(quad.meshes.length == 1);
    quad.meshes[0].alphas.length = texNum;
    assert(alphaNum() == texNum);

    int s = width*width;
    for(int i=0;i<texNum;i++)
      quad.meshes[0].alphas[i].buffer = data[i*s..(i+1)*s];
  }

  // Get the height offset
  float getHeight()
  {
    if(hasMesh)
      {
        assert(quad.meshes.length == 1);
        return quad.meshes[0].info.heightOffset;
      }
    else
      // The default mesh starts at 2048 = 256*8 units below water
      // level.
      return -256;
  }

  bool isEmpty()
  {
    return (data.length == 0) && !hasMesh;
  }

  bool hasAlpha()
  {
    assert(isAlpha == (quad.info.level==1));
    return isAlpha;
  }

  int alphaNum()
  {
    assert(hasAlpha());
    assert(quad.meshes.length == 1);
    return quad.meshes[0].alphas.length;
  }

  int getAlphaTex(int alpha)
  {
    return quad.meshes[0].alphas[alpha].info.texName;
  }

  void setAlphaTex(int alpha, int index)
  {
    quad.meshes[0].alphas[alpha].info.texName = index;

    // Create the alpha material name.
    char[] aname =
      "ALPHA_" ~ .toString(quad.info.cellX)
      ~ "_" ~ .toString(quad.info.cellY)
      ~ "_" ~ .toString(alpha)
      ~ "_" ~ .toString(index);

    quad.meshes[0].alphas[alpha].info.alphaName = cache.addString(aname);
  }

  void setTexName(char[] tex)
  {
    assert(!isEmpty());
    assert(quad.meshes.length == 1);
    quad.meshes[0].info.texName = cache.addString(tex);    
  }

  void save(char[] tex)
  {
    assert(!isEmpty());
    assert(!hasAlpha());

    // Store the filename in the cache, so the runtime can find the
    // file
    setTexName(tex);

    tex = cacheDir ~ tex;

    writefln("  Creating ", tex);

    terr_saveImage(data.ptr, width, toStringz(tex));
  }

  // Calculate the texture name for this quad
  char[] getPNGName(bool isDefault)
  {
    int X = quad.info.cellX;
    int Y = quad.info.cellY;
    int level = quad.info.level;

    char[] outname = toString(level) ~ "_";

    if(isDefault)
      outname ~= "default";
    else
      outname ~= toString(X) ~ "_" ~ toString(Y);

    outname ~= ".png";

    return outname;
  }

  // Resize the image
  void resize(int toSize)
  {
    assert(!isEmpty());
    assert(!hasAlpha());

    // Make sure we're scaling down, since we never gain anything by
    // scaling up.
    assert(toSize < width);

    ubyte newBuf[] = new ubyte[toSize*toSize*3];

    // Resize
    terr_resize(data.ptr, newBuf.ptr, width, toSize);

    // Replace the old buffer
    delete data;
    width = toSize;
    data = newBuf;
  }

  void kill()
  {
    if(!isEmpty())
      {
        // This takes care of both normal image data and alpha maps.
        delete data;

        if(hasMesh)
          delete quad.meshes[0].vertexBuffer;
      }
  }

  void allocMesh(int size)
  {
    quad.meshes.length = 1;

    MeshHolder *mh = &quad.meshes[0];
    MeshInfo *mi = &mh.info;

    mi.vertRows = size;
    mi.vertCols = size;
    // 2 height bytes + 3 normal components = 5 bytes per vertex.
    mh.vertexBuffer = new byte[5*size*size];

    hasMesh = true;
  }
}

// Default textures
GenLevelResult[] defaults;

// Generates the default texture images "2_default.png" etc
void genDefaults()
{
  scope auto _trc = new MTrace("genDefaults");

  int size = texSizes.length-1;
  defaults.length = size;

  for(int i=1; i<size; i++)
    defaults[i].quad.info.level = i;

  // Sending null as the first parameter tells the function to only
  // render the default background.
  assert(size > 2);
  genLevel2Map(null, defaults[2]);

  for(int i=3; i<size; i++)
    mergeMaps(null, defaults[i]);
}

// Generates common mesh information that's stored in the .index
// file. This includes the x/y coordinates of meshes on each level,
// the u/v texture coordinates, and the triangle index data.
void genIndexData()
{
  scope auto _trc = new MTrace("genIndexData");

  // FIXME: Do this at runtime.
  for(int lev=1; lev<=6; lev++)
    {
      // Make a new buffer to store the data
      int size = 65*65*4;
      auto vertList = new float[size];
      int index = 0;

      // Find the vertex separation for this level. The vertices are
      // 128 units apart in each cell (level 1), and for each level
      // above that we double the distance. This gives 128 * 2^(lev-1)
      // = 64*2^lev.
      int vertSep = 64 << lev;

      // Loop over all the vertices in the mesh.
      for(int y=0; y<65; y++)
        for(int x=0; x<65; x++)
          {
            // X and Y
            vertList[index++] = x*vertSep;
            vertList[index++] = y*vertSep;

            // U and V (texture coordinates)
            float u = x/64.0;
            float v = y/64.0;
            assert(u>=0&&v>=0);
            assert(u<=1&&v<=1);
    
            vertList[index++] = u;
            vertList[index++] = v;
          }
      assert(index == vertList.length);
      // Store the buffer
      cache.addVertexBuffer(lev,vertList);
    }

  // index stuff already ported
}

void genLevel(int level, int X, int Y, ref GenLevelResult result,
              bool makeData = true)
{
  scope auto _trc = new MTrace(format("genLevel(%s,%s,%s)",level,X,Y));
  result.quad.info.cellX = X;
  result.quad.info.cellY = Y;
  result.quad.info.level = level;
  result.quad.info.worldWidth = 8192 << (level-1);

  assert(result.isEmpty);

  // Level 1 (most detailed) is handled differently from the
  // other leves.
  if(level == 1)
    {
      assert(makeData);

      if(!mwland.hasData(X,Y))
        // Oops, there's no data for this cell. Skip it.
        return;

      // The mesh is generated in pieces rather than as one part.
      genLevel1Meshes(result);

      // We also generate alpha maps instead of the actual textures.
      genCellAlpha(result);

      if(!result.isEmpty())
        {
          // Store the information we just created
          assert(result.hasAlpha());
          cache.writeQuad(result.quad);
        }

      return;
    }
  assert(level > 1);

  // Number of cells along one side in each sub-quad (not in this
  // quad)
  int cells = 1 << (level-2);

  // Call the sub-levels and store the result
  GenLevelResult sub[4];
  genLevel(level-1, X, Y, sub[0]);             // NW
  genLevel(level-1, X+cells, Y, sub[1]);       // NE
  genLevel(level-1, X, Y+cells, sub[2]);       // SW
  genLevel(level-1, X+cells, Y+cells, sub[3]); // SE

  // Make sure we deallocate everything when the function exists
  scope(exit)
    {
      foreach(ref s; sub)
        s.kill();
    }

  // Mark the sub-quads that have data
  bool anyUsed = false;
  for(int i=0;i<4;i++)
    {
      bool used = !sub[i].isEmpty();
      result.quad.info.hasChild[i] = used;
      anyUsed = anyUsed || used;
    }

  if(!anyUsed)
    {
      // If our children are empty, then we are also empty.
      assert(result.isEmpty());
      return;
    }

  if(makeData)
    {
      if(level == 2)
        // For level==2, generate a new texture from the alpha maps.
        genLevel2Map(sub, result);
      else
        // Level 3+, merge the images from the previous levels
        mergeMaps(sub, result);

      // Create the landscape mesh by merging the result from the
      // children.
      mergeMesh(sub, result);
    }

  // Store the result in the cache file
  cache.writeQuad(result.quad);
}

// Generate mesh data for one cell
void genLevel1Meshes(ref GenLevelResult res)
{
  // Constants
  int intervals = 64;
  int vertNum = intervals+1;
  int vertSep = 128;

  // Allocate the mesh buffer
  res.allocMesh(vertNum);

  int cellX = res.quad.info.cellX;
  int cellY = res.quad.info.cellY;
  assert(res.quad.info.level==1);

  MeshHolder *mh = &res.quad.meshes[0];
  MeshInfo *mi = &mh.info;

  // Set some basic data
  mi.worldWidth = vertSep*intervals;
  assert(mi.worldWidth == 8192);

  auto land = mwland.getLandData(cellX, cellY);

  byte[] heightData = land.vhgt.heightData;
  byte[] normals = land.normals;
  mi.heightOffset = land.vhgt.heightOffset;

  float max=-1000000.0;
  float min=1000000.0;

  byte[] verts = mh.vertexBuffer;
  int index = 0;

  // Loop over all the vertices in the mesh
  float rowheight = mi.heightOffset;
  float height;
  for(int y=0; y<65; y++)
    for(int x=0; x<65; x++)
      {
        // Offset of this vertex within the source buffer
        int offs=y*65+x;

        // The vertex data from the ESM
        byte data = heightData[offs];

        // Write the height value as a short (2 bytes)
        *(cast(short*)&verts[index]) = data;
        index+=2;

        // Calculate the height here, even though we don't store
        // it. We use it to find the min and max values.
        if(x == 0)
          {
            // Set the height to the row height
            height = rowheight;

            // First value in each row adjusts the row height
            rowheight += data;
          }
        // Adjust the accumulated height with the new data.
        height += data;

        // Calculate the min and max
        max = height > max ? height : max;
        min = height < min ? height : min;

        // Store the normals
        for(int k=0; k<3; k++)
          verts[index++] = normals[offs*3+k];
      }

  // Make sure we wrote exactly the right amount of data
  assert(index == verts.length);

  // Store the min/max values
  mi.minHeight = min * 8;
  mi.maxHeight = max * 8;
}

// Generate the alpha splatting bitmap for one cell.
void genCellAlpha(ref GenLevelResult res)
{
  scope auto _trc = new MTrace("genCellAlpha");

  int cellX = res.quad.info.cellX;
  int cellY = res.quad.info.cellY;
  assert(res.quad.info.level == 1);

  // Set the texture name - it's used internally as the material name
  // at runtime.
  assert(res.quad.meshes.length == 1);
  res.setTexName("AMAT_"~toString(cellX)~"_"~toString(cellY));

  // List of texture indices for this cell. A cell has 16x16 texture
  // squares.
  int ltex[16][16];

  auto ltexData = mwland.getLTEXData(cellX, cellY);

  // A map from the global texture index to the local index for this
  // cell.
  int[int] textureMap;

  int texNum = 0; // Number of local indices

  // Loop through all the textures in the cell and get the indices
  bool isDef = true;
  for(int ty = 0; ty < 16; ty++)
    for(int tx = 0; tx < 16; tx++)
      {
        // Get the texture in a given cell
        char[] textureName = ltexData.getTexture(tx,ty);

        // If the default texture is used, skip it. The background
        // texture covers it (for now - we might change that later.)
        if(textureName == "")
          {
            ltex[ty][tx] = -1;
            continue;
          }

        isDef = false;

        // Store the global index
        int index = cache.addTexture(textureName);
        ltex[ty][tx] = index;

        // Add the index to the map
        if(!(index in textureMap))
          textureMap[index] = texNum++;
      }

  assert(texNum == textureMap.length);

  // If we only found default textures, exit now.
  if(isDef)
    return;

  int imageRes = texSizes[1];
  int dataSize = imageRes*imageRes;

  // Number of alpha pixels per texture square
  int pps = imageRes/16;

  // Make sure there are at least as many alpha pixels as there are
  // textures
  assert(imageRes >= 16);
  assert(imageRes%16 == 0);
  assert(pps >= 1);
  assert(texNum >= 1);

  // Allocate the alpha images
  res.allocAlphas(imageRes, texNum);
  assert(res.hasAlpha() && !res.isEmpty());

  // Write the indices to the result list
  foreach(int global, int local; textureMap)
    res.setAlphaTex(local, global);

  ubyte *uptr = res.data.ptr;

  // Loop over all textures again. This time, do alpha splatting.
  for(int ty = 0; ty < 16; ty++)
    for(int tx = 0; tx < 16; tx++)
      {
        // Get the global texture index for this square, if any.
        int index = ltex[ty][tx];
        if(index == -1)
          continue;

        // Get the local index
        index = textureMap[index];

        // Get the offset of this square
        long offs = index*dataSize + pps*(ty*imageRes + tx);

        // FIXME: Make real splatting later. This is just
        // placeholder code.

        // Set alphas to full for this square
        for(int y=0; y<pps; y++)
          for(int x=0; x<pps; x++)
            {
              long toffs = offs + imageRes*y + x;
              assert(toffs < dataSize*texNum);
              uptr[toffs] = 255;
            }
      }
}

// Generate a texture for level 2 from four alpha maps generated in
// level 1.
void genLevel2Map(GenLevelResult maps[], ref GenLevelResult res)
{
  int fromSize = texSizes[1];
  int toSize = texSizes[2];

  struct LtexList
  {
    int[4] inds;
  }

  // Create an overview of which texture is used where. The 'key' is
  // the global texture index, the 'value' is the corresponding
  // local indices in each of the four submaps.
  HashTable!(int, LtexList) lmap;

  if(maps.length) // An empty list means use the default texture
    for(int mi=0;mi<4;mi++)
      {
        if(maps[mi].isEmpty())
          continue;

        assert(maps[mi].hasAlpha());
        assert(maps[mi].width == fromSize);

        for(int ltex=0;ltex<maps[mi].alphaNum();ltex++)
          {
            // Global index for this texture
            int gIndex = maps[mi].getAlphaTex(ltex);

            // Store it in the map.
            LtexList *v;
            if(lmap.insertEdit(gIndex, v))
              // If a new value was inserted, set all the values to -1
              v.inds[] = -1;

            v.inds[mi] = ltex;
          }
      }

  float scale = TEX_SCALE/2;

  char[] materialName = "MAT" ~ toString(mCount++);

  terr_makeLandMaterial(toStringz(materialName),scale);

  // Loop through all our textures
  if(maps.length)
    foreach(int gIndex, LtexList inds; lmap)
      {
        char[] name = cache.getString(gIndex);

        // Skip default image, if present
        if ( name.iBegins("_land_default.") )
          continue;

        // Create a new alpha texture and get a pointer to the pixel
        // data
        char *alphaName = toStringz(materialName ~ "_A_" ~ name);
        auto pDest = terr_makeAlphaLayer(alphaName, 2*fromSize);

        // Fill in the alpha values. TODO: Do all this with slices instead.
        memset(pDest, 0, 4*fromSize*fromSize);
        for(int i=0;i<4;i++)
          {
            // Does this sub-image have this texture?
            int index = inds.inds[i];
            if(index == -1) continue;

            assert(!maps[i].isEmpty());

            // Find the right sub-texture in the alpha map
            ubyte *from = maps[i].data.ptr +
              (fromSize*fromSize)*index;

            // Find the right destination pointer
            int x = i%2;
            int y = i/2;
            ubyte *to = pDest + x*fromSize + y*fromSize*fromSize*2;

            // Copy the rows one by one
            for(int row = 0; row < fromSize; row++)
              {
                assert(to+fromSize <= pDest + 4*fromSize*fromSize);
                memcpy(to, from, fromSize);
                to += 2*fromSize;
                from += fromSize;
              }
          }

        terr_closeAlpha(alphaName, toStringz(name), scale);
      }

  // Create the result buffer
  res.allocImage(toSize);

  // Texture file name
  char[] outname = res.getPNGName(maps.length == 0);

  terr_cleanupAlpha(toStringz(outname), res.data.ptr, toSize);
  res.save(outname);
}

void mergeMaps(GenLevelResult[] maps, ref GenLevelResult res)
{
  int level = res.quad.info.level;

  assert(texSizes.length > level);
  assert(level > 2);
  int fromSize = texSizes[level-1];
  int toSize = texSizes[level];

  // Create a new image buffer large enough to hold the four
  // sub textures
  res.allocImage(fromSize*2);

  // Add the four sub-textures
  for(int mi=0;mi<4;mi++)
    {
      ubyte[] src;

      // Use default texture if no source is present
      if(maps.length == 0 || maps[mi].isEmpty())
        src = defaults[level-1].data;
      else
        src = maps[mi].data;

      assert(src.length == 3*fromSize*fromSize);

      // Find the sub-part of the destination buffer to write to
      int x = (mi%2) * fromSize;
      int y = (mi/2) * fromSize;

      // Copy the image into the new buffer
      copyBox(src, res.data, fromSize, fromSize*2, x, y, 3);
    }

  // Resize image if necessary
  if(toSize != 2*fromSize)
    res.resize(toSize);

  // Texture file name
  char[] outname = res.getPNGName(maps.length == 0);

  // Save the image
  res.save(outname);
}

// Copy from one buffer into a sub-region of another buffer
void copyBox(ubyte[] src, ubyte[] dst,
             int srcWidth, int dstWidth,
             int dstX, int dstY, int pixSize)
{
  int fskip = srcWidth * pixSize;
  int tskip = dstWidth * pixSize;
  int rows = srcWidth;
  int rowSize = srcWidth*pixSize;

  assert(src.length == pixSize*srcWidth*srcWidth);
  assert(dst.length == pixSize*dstWidth*dstWidth);
  assert(srcWidth <= dstWidth);
  assert(dstX <= dstWidth-srcWidth && dstY <= dstWidth-srcWidth);

  // Source and destination pointers
  ubyte *from = src.ptr;
  ubyte *to = dst.ptr + dstY*tskip + dstX*pixSize;

  for(;rows>0;rows--)
    {
      memcpy(to, from, rowSize);
      to += tskip;
      from += fskip;
    }
}

// Create the mesh for this level, by merging the meshes from the
// previous levels.
void mergeMesh(GenLevelResult[] sub, ref GenLevelResult res)
{
  // How much to shift various numbers to the left at this level
  // (ie. multiply by 2^shift). The height at each vertex is
  // multiplied by 8 in each cell to get the final value. However,
  // when we're merging two cells (in each direction), we have to
  // scale down all the height values by 2 in order to fit the result
  // in one byte. This means multiplying the factor by 2 for each
  // level above the cell level.
  int shift = res.quad.info.level - 1;
  assert(shift >= 1);
  assert(sub.length == 4);

  // Allocate the result buffer
  res.allocMesh(65);

  MeshHolder *mh = &res.quad.meshes[0];
  MeshInfo *mi = &mh.info;

  // Basic info
  mi.worldWidth = 8192 << shift;

  // Copy the mesh height from the top left mesh
  mi.heightOffset = sub[0].getHeight();

  // Output buffer
  byte verts[] = mh.vertexBuffer;

  // Bytes per vertex
  const int VSIZE = 5;

  // Used to calculate the max and min heights
  float minh = 300000.0;
  float maxh = -300000.0;

  foreach(si, s; sub)
    {
      int SX = si % 2;
      int SY = si / 2;

      // Find the offset in the destination buffer
      int dest = SX*32 + SY*65*32;
      dest *= VSIZE;

      void putValue(int val)
        {
          assert(val >= short.min && val <= short.max);
          *(cast(short*)&verts[dest]) = val;
          dest += 2;
        }

      if(s.hasMesh)
        {
          auto m = &s.quad.meshes[0];
          auto i = &m.info;

          minh = min(minh, i.minHeight);
          maxh = max(maxh, i.maxHeight);

          byte[] source = m.vertexBuffer;
          int src = 0;

          int getValue()
            {
              int s = *(cast(short*)&source[src]);
              src += 2;
              return s;
            }

          // Loop through all the vertices in the mesh
          for(int y=0;y<33;y++)
            {
              // Skip the first row in the mesh if there was a mesh
              // above us. We assume that the previously written row
              // already has the correct information.
              if(y==0 && SY != 0)
                {
                  src += 65*VSIZE;
                  dest += 65*VSIZE;
                  continue;
                }

              // Handle the first vertex of the row outside the
              // loop.
              int height = getValue();

              // If this isn't the very first row, sum up two row
              // heights and skip the first row.
              if(y!=0)
                {
                  // Skip the rest of the row.
                  src += 64*VSIZE + 3;

                  // Add the second height
                  height += getValue();
                }

              putValue(height);

              // Copy the normal
              verts[dest++] = source[src++];
              verts[dest++] = source[src++];
              verts[dest++] = source[src++];

              // Loop through the remaining 64 vertices in this row,
              // processing two at a time.
              for(int x=0;x<32;x++)
                {
                  height = getValue();

                  // Sum up the next two heights
                  src += 3; // Skip normal
                  height += getValue();

                  // Set the height
                  putValue(height);

                  // Copy the normal
                  verts[dest++] = source[src++];
                  verts[dest++] = source[src++];
                  verts[dest++] = source[src++];
                }
              // Skip to the next row
              dest += 32*VSIZE;
            }
          assert(src == source.length);
        }
      else
        {
          minh = min(minh, -2048);
          maxh = max(maxh, -2048);

          // Set all the vertices to zero.
          for(int y=0;y<33;y++)
            {
              if(y==0 && SY != 0)
                {
                  dest += 65*VSIZE;
                  continue;
                }

              for(int x=0;x<33;x++)
                {
                  if(x==0 && SX != 0)
                    {
                      dest += VSIZE;
                      continue;
                    }

                  // Zero height and vertical normal
                  verts[dest++] = 0;
                  verts[dest++] = 0;
                  verts[dest++] = 0;
                  verts[dest++] = 0;
                  verts[dest++] = 0x7f;
                }
              // Skip to the next row
              dest += 32*VSIZE;
            }
        }
    }

  mi.minHeight = minh;
  mi.maxHeight = maxh;
  assert(minh <= maxh);
}

// ------- OLD CODE - use these snippets later -------

// About segments:
/* NOTES for the gen-phase: Was:
// This is pretty messy. Btw: 128*16 == 2048 ==
// CELL_WIDTH/4
// 65 points across one cell means 64 intervals, and 17 points

// means 16=64/4 intervals. So IOW the number of verts when
// dividing by D is (65-1)/D + 1 = 64/D+1, which means that D
// should divide 64, that is, be a power of two < 64.

addNewObject(Ogre::Vector3(x*16*128, 0, y*16*128), //pos
17, //size
false, //skirts
0.25f, float(x)/4.0f, float(y)/4.0f);//quad seg location
*/

/* This was also declared in the original code, you'll need it
   when creating the cache data

   size_t vw = mWidth; // mWidth is 17 or 65
   if ( mUseSkirts ) vw += 2; // skirts are used for level 2 and up
   vertCount=vw*vw;
*/

/**
 * @brief fills the vertex buffer with data
 * @todo I don't think tex co-ords are right
 void calculateVertexValues()
 {
 int start = 0;
 int end = mWidth;

 if ( mUseSkirts )
 {
 --start;
 ++end;
 }

 for ( int y = start; y < end; y++ )
 for ( int x = start; x < end; x++ )
 {
 if ( y < 0 || y > (mWidth-1) || x < 0 || x > (mWidth-1) )
 {
 // These are the skirt vertices. 'Skirts' are simply a
 // wall at the edges of the mesh that goes straight down,
 // cutting off the posibility that you might see 'gaps'
 // between the meshes. Or at least I think that's the
 // intention.

 assert(mUseSkirts);

 // 1st coordinate
 if ( x < 0 )
 *verts++ = 0;
 else if ( x > (mWidth-1) )
 *verts++ = (mWidth-1)*getVertexSeperation();
 else
 *verts++ = x*getVertexSeperation();

 // 2nd coordinate
 *verts++ = -4096; //2048 below base sea floor height

 // 3rd coordinate
 if ( y < 0 )
 *verts++ = 0;
 else if ( y > (mWidth-1) )
 *verts++ = (mWidth-1)*getVertexSeperation();
 else
 *verts++ = y*getVertexSeperation();

 // No normals
 for ( Ogre::uint i = 0; i < 3; i++ )
 *verts++ = 0;

 // It shouldn't matter if these go over 1
 float u = (float)(x) / (mWidth-1);
 float v = (float)(y) / (mWidth-1);
 *verts++ = u;
 *verts++ = v;
 }
 else // Covered already

 void calculateIndexValues()
 {
 size_t vw = mWidth-1;
 if ( mUseSkirts ) vw += 2;

 const size_t indexCount = (vw)*(vw)*6;

 //need to manage allocation if not null
 assert(mIndices==0);

 // buffer was created here

 bool flag = false;
 Ogre::uint indNum = 0;
 for ( Ogre::uint y = 0; y < (vw); y+=1 ) {
 for ( Ogre::uint x = 0; x < (vw); x+=1 ) {

 const int line1 = y * (vw+1) + x;
 const int line2 = (y + 1) * (vw+1) + x;

 if ( flag ) {
 *indices++ = line1;
 *indices++ = line2;
 *indices++ = line1 + 1;

 *indices++ = line1 + 1;
 *indices++ = line2;
 *indices++ = line2 + 1;
 } else {
 *indices++ = line1;
 *indices++ = line2;
 *indices++ = line2 + 1;

 *indices++ = line1;
 *indices++ = line2 + 1;
 *indices++ = line1 + 1;
 }
 flag = !flag; //flip tris for next time

 indNum+=6;
 }
 flag = !flag; //flip tries for next row
 }
 assert(indNum==indexCount);
 //return mIndices;
 }
*/
