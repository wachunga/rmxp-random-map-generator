#==============================================================================
# ** Random Map Generator
#------------------------------------------------------------------------------
# version 0.51, 25-09-2005
# by Wachunga, based on Jamis Bruck's D&D dungeon generator
# See https://github.com/wachunga/rmxp-random-map-generator for details
#==============================================================================
  
$save_map_list = []

class Game_Map

  alias old_setup_map setup_map
  def setup_map(map_id)
    old_setup_map(map_id)
    tags = map_name.delete(' ').scan(/<[A-Za-z0-9_.]+>/) # get all the tags
    if not tags.empty? and tags[0].upcase == '<RAND>'
      tags.shift # remove the first element
      if not tags.empty? and tags[0].upcase == '<SAVE>'
        $save_map_list.push(@map_id)
        tags.shift
      end
      if not tags.empty?
        for i in 0...tags.length
          tags[i] = tags[i].delete("<>").to_f
        end
      end
      startX = 0; startY = 2 # default starting position
      endX = @map.width-1; endY = @map.height-1 # default ending position
      # note that these defaults haven't yet been tested much
      for i in @map.events.keys
        if @map.events[i].name.upcase == '<START>'
          startX = @map.events[i].x
          startY = @map.events[i].y
        elsif @map.events[i].name.upcase == '<END>'
          endX = @map.events[i].x
          endY = @map.events[i].y
        end
      end
      # note that *tags will expand the array, passing individual elements
      # (if any) as arguments (randomness, sparsity and chance to remove deadends)
      # e.g. if map name includes "<rand><0.5><10><0.6>", then the call is:
      # maze = Maze.new( @map.width, @map.height, startX, startY, endX, endY, 0.5, 10, 0.6)
      maze = Maze.new( @map.tileset_id, @map.width, @map.height, startX, startY, endX, endY, *tags)
      # set these up for teleports into the maze
      maze.draw
    end
  end

  def data=(newdata)
    @map.data = newdata
  end
  
  def map_name
    return load_data("Data/MapInfos.rxdata")[@map_id].name
  end  
  
end



class Maze

  WALL = 0
  PASSAGE = 1

  attr_reader   :width
  attr_reader   :height
  attr_reader   :startX
  attr_reader   :startY
  attr_reader   :endX
  attr_reader   :endY

  def initialize(pTileset, pWidth, pHeight, pStartX, pStartY, pEndX, pEndY,
                  pRandomness=0.5, pSparsity=3, pRemovalChance=0.5)
    @tileset = pTileset
    @width = pWidth
    @height = pHeight
    @startX = pStartX
    @startY = pStartY
    @endX = pEndX
    @endY = pEndY

    # prepare the base matrix
    @base = Direction_Matrix.new(@width, @height, @startX, @startY, @endX, @endY, pRandomness, pSparsity, pRemovalChance)

    # reset everything in the Tile module to 0
    Tile.floor = 0
    Tile.wall = 0
    Tile.wallFace = 0

    # prepare the tiles depending on the tileset
    if @tileset == 27
       Tile.setFloor(2,1) # 384
       Tile.setWall(1,2) # 48-95
       Tile.setWallFace(4,2) # 401
    elsif @tileset == 51
       Tile.setFloor(2,2) # 384
       Tile.setWall(2,1) # 385     
    #elsif @tileset == 'y'
    # others go here
    else
       # nothing specified so just use default
       Tile.setFloor(2,1) # 384
       Tile.setWall(1,2) # 48-95
    end

    # if no wall face is being used, then Y locations should be ODD (opposite of
    # when using a wall face)
    if (@startX % 2) == 0 and @startX != 0 and @startX != @width-1
      print 'Warning: player may start in a wall (starting X location is even).'
    end     
    if Tile.wallFace != 0
      if (@startY % 2) != 0 and @startY != 0 and @startY != @height-1
        print 'Warning: player may start in a wall (starting Y location is odd).'
      end
    else
      if (@startY % 2) == 0 and @startY != 0 and @startY != @height-1
        print 'Warning: player may start in a wall (starting Y location is even).'
      end      
    end
    
    if (@endX % 2) == 0 and @endX != 0 and @endX != @width-1
      print 'Warning: maze end may be unreachable (X location is even).'
    end     
    if Tile.wallFace != 0    
      if (@endY % 2) != 0 and @endY != 0 and @endY != @height-1
        print 'Warning: maze end may be unreachable (Y location is odd).'
      end      
    else
      if (@endY % 2) == 0 and @endY != 0 and @endY != @height-1
        print 'Warning: maze end may be unreachable (Y location is even).'
      end        
    end
    
    
    # initialized with all walls
    @matrix = Array.new(@width, WALL)
    for i in 0...@width
        @matrix[i] = Array.new(@height, WALL)
      end

    setup
  end
 

=begin
   Sets up the actual maze from a base matrix of only directions.
   (Basic algorithm from Jamis Buck's D&D dungeon generator.)
=end
  def setup
   
    for x in 0...@base.width
      for y in 0...@base.height
        dir = @base.matrix[x][y]
        if (dir != 0) # not sparsified
          @matrix[x*2+1][y*2+1] = PASSAGE
        end
        if ((dir & Direction_Matrix::NORTH) != 0)
          @matrix[x*2+1][y*2] = PASSAGE
        end
        if ((dir & Direction_Matrix::WEST) != 0)
          @matrix[x*2][y*2+1] = PASSAGE
        end
        # only necessary for right edge start/exit
        if ((dir & Direction_Matrix::EAST) != 0)
          @matrix[x*2+2][y*2+1] = PASSAGE
          # if extra wall is there, need to "dig deeper"
          if (@width % 2) == 0 and x*2+3 == @width-1
            @matrix[x*2+3][y*2+1] = PASSAGE
          end
        end
        # only necessary for bottom edge start/exit
        if ((dir & Direction_Matrix::SOUTH) != 0)
          @matrix[x*2+1][y*2+2] = PASSAGE
          # if extra wall is there, need to "dig deeper"
          if (@height % 2) == 0 and y*2+3 == @height-1
            @matrix[x*2+1][y*2+3] = PASSAGE
          end
        end         
      end
    end     
  end

=begin
   Display the matrix in an ASCII table (useful for debugging).
   (Much more readable if you're using a monospaced font for dialog boxes.)
=end
  def display
    char_array = Array.new(@width, 0)
    for i in 0...@width
    char_array[i] = Array.new(@height, 0)
    end
  
    for x in 0...@width
      for y in 0...@height
        tile = @matrix[x][y]
        char = ' '
        if ((tile == WALL)) then char << '#' end
        if ((tile == PASSAGE)) then char << ' ' end
        char_array[y][x] = char
      end
    end
  
    display = ''
    for i in 0...@height
      display << char_array[i].flatten.to_s << "\n"
    end
    print display
  end


=begin
   Draw the maze using the map's tileset.
=end
  def draw
    newdata = Table.new(@width, @height, 3)
    # put down the floor on the first layer (z=0)
    z = 0
    for x in 0...@width
      for y in 0...@height
        newdata[x,y,z] = Tile.floor
      end
    end

    # now for the walls on the second layer (z=1)
    z = 1

    if Tile.wall.type.to_s.upcase != "HASH" # not autotiles
      for x in 0...@width
        for y in 0...@height     
          newdata[x,y,z] = Tile.wall if (@matrix[x][y] == WALL)
        end
      end
    else # autotiles...
      for x in 0...@width
        for y in 0...@height
          # skip passages
          if (@matrix[x][y] == PASSAGE) then next end
          
          # calculate adjacent walls
          adj = ''
            
          if (x == 0)
            adj << '147'
          else
            if (y == 0) then adj << '1'
            else
              if (@matrix[x-1][y-1] == WALL) then adj << '1' end
            end
            if (@matrix[x-1][y] == WALL) then adj << '4' end
            if (y == @height-1) then adj << '7'
            else
              if (@matrix[x-1][y+1] == WALL) then adj << '7' end
            end
          end
        
          if (x == @width-1)
            adj << '369'
          else
            if (y == 0) then adj << '3'
            else
              if (@matrix[x+1][y-1] == WALL) then adj << '3' end
            end
            if (@matrix[x+1][y] == WALL) then adj << '6' end
            if (y == @height-1) then adj << '9'
            else
              if (@matrix[x+1][y+1] == WALL) then adj << '9' end
            end
          end
        
          if (y == 0)
            adj << '2'
          else
            if (@matrix[x][y-1] == WALL) then adj << '2' end
          end
          if (y == @height-1)
            adj << '8'
          else
            if (@matrix[x][y+1] == WALL) then adj << '8' end
          end

          # if no adjacent walls, set it as 0
          if (adj == '') then adj = '0' end
        
          # convert to an array, sort, and then back to a string
          adj = adj.split(//).sort.join
          
          newdata[x,y,z] = eval 'Tile.wall[adj.to_i]'

          # show single wall tile beneath bottom-facing walls
          if Tile.wallFace > 0
            if not adj.include?('8')
              newdata[x,y+1,z] = Tile.wallFace
            end
          end
        end # for 
      end # for 
    end # if-else
    $game_map.data = newdata
  end # draw method

end



=begin
    A matrix whose elements each contains 1-4 directions (north, east, south,
    west) forming the basis for a maze or dungeon.
    
    (Basic algorithms from Jamis Buck's D&D dungeon generator.)
=end
class Direction_Matrix
  NORTH = 0b00001
  EAST = 0b00010
  SOUTH = 0b00100
  WEST = 0b01000
  ALL_DIRS = NORTH | EAST | SOUTH | WEST
  FLAG = 0b10000
  
  attr_reader :width
  attr_reader :height
  attr_reader :matrix  
    
  def initialize(pWidth, pHeight, pStartX, pStartY, pEndX, pEndY,
                pRandomness, pSparsity, pRemovalChance)
    @width = pWidth/2
    @height = pHeight/2
    # convert to Direction_Matrix's dimensions
    @startX = pStartX/2
    @startY = pStartY/2
    @endX = pEndX/2
    @endY = pEndY/2     

    # if even, decrement by 1
    @width -= 1 if (pWidth % 2 == 0)
    @height -= 1 if (pHeight % 2 == 0)    
    if @startX != 0
      @startX -= 1 if (pStartX % 2 == 0)
    end
    if @startY != 0    
      @startY -= 1 if (pStartY % 2 == 0)
    end
    if @endX != 0
      @endX -= 1 if (pEndX % 2 == 0)
    end
    if @endY != 0    
      @endY -= 1 if (pEndY % 2 == 0)
    end      

    # handle a weird situation
    if @startX >= @width then @startX = @width-1 end
    if @endX >= @width then @endX = @width-1 end
       
    @randomness = pRandomness
    @sparsity = pSparsity
    @removalChance = pRemovalChance
    
    @matrix = Array.new(@width, 0)
    for i in 0...@width
      @matrix[i] = Array.new(@height, 0)
    end
    
    generate

    # we need the original start/end locations and width/height in these cases
    if pStartY == 0
      @matrix[@startX][@startY] |= NORTH
    elsif pStartX == 0
      @matrix[@startX][@startY] |= WEST
    elsif (pStartX == @width*2+1 and (pWidth % 2) == 0) or
      (pStartX == @width*2 and (pWidth % 2) != 0)
      @matrix[@startX][@startY] |= EAST
    elsif (pStartY == @height*2+1 and (pHeight % 2) == 0) or
      (pStartY == @height*2 and (pHeight % 2) != 0)
      @matrix[@startX][@startY] |= SOUTH
    end
    
    if pEndY == 0
      @matrix[@endX][@endY] |= NORTH
    elsif pEndX == 0
      @matrix[@endX][@endY] |= WEST
    elsif (pEndX == @width*2+1 and (pWidth % 2) == 0) or
      (pEndX == @width*2 and (pWidth % 2) != 0)
      @matrix[@endX][@endY] |= EAST
    elsif (pEndY == @height*2+1 and (pHeight % 2) == 0) or
      (pEndY == @height*2 and (pHeight % 2) != 0)
      @matrix[@endX][@endY] |= SOUTH
    end     

    sparsify
    removeDeadends    
    
  end

  
=begin
   The algorithm for generating random mazes is as follows:
   (1) randomly pick a starting tile from the map
   (2) pick a random direction and move that way as long as there
       is a new tile in that direction and hasn't been visited yet
   (3) perform (2) until there is no valid direction to move in, then
       pick a new tile that HAS been visited before and perform (2)
       and (3) until all the tiles have been visited  
=end
  def generate
   testedDirs = lastDir = straightStretch = 0

    x = @startX
    y = @startY 
    
   remaining = @width * @height - 1

   # loop for all remaining tiles
   while (remaining > 0)

       if (testedDirs == ALL_DIRS)
           # we're stuck so choose an already-visited tile
           while true
               x = rand(@width)
               y = rand(@height)
               break if @matrix[x][y] != 0
           end
           testedDirs = @matrix[x][y]
       end

       # eliminate impossible directions
       if (x < 1) then testedDirs |= WEST
       elsif (x+1 > @width) then testedDirs |= EAST
       end
       
       if (y < 1) then testedDirs |= NORTH
       elsif (y+1 > @height) then testedDirs |= SOUTH
       end

       randomSelection = false

       # depending on randomness parameter of map,
       # either select direction randomly or continue straight
       # (but no stretch can be longer than half the width/height)
       if ( rand < @randomness)
           randomSelection = true
       else
           case lastDir
               when NORTH
                   if ( y>0 and straightStretch < @height/2 and @matrix[x][y-1]==0 )
                       direction = lastDir
                   else randomSelection = true
                   end
               when EAST
                   if ( x+1<@width and straightStretch < @width/2 and @matrix[x+1][y]==0 )
                       direction = lastDir
                   else randomSelection = true
                   end
               when SOUTH
                   if ( y+1<@height and straightStretch < @height/2 and @matrix[x][y+1]==0 )
                       direction = lastDir
                   else randomSelection = true
                   end
               when WEST
                   if ( x>0 and straightStretch < @width/2 and @matrix[x-1][y]==0 )
                       direction = lastDir
                   else randomSelection = true
                   end
               else randomSelection = true
           end
       end

       if (randomSelection)

           # reset
           direction = 0
           straightStretch = 0

           # pick random direction
           # keep trying until a valid one is found
           while ( (direction == 0) or ((testedDirs & direction) != 0) )
               temp_x = x
               temp_y = y
               case rand(4)
                   when 0 # north
                       if (y > 0) then direction = NORTH; temp_y-=1
                       else testedDirs |= NORTH
                       end
                   when 1 # east
                       if (x+1 < @width) then direction = EAST; temp_x+=1
                       else testedDirs |= EAST
                       end
                   when 2 # south
                       if (y+1 < @height) then direction = SOUTH; temp_y+=1
                       else testedDirs |= SOUTH
                       end
                   when 3 # west
                       if (x > 0) then direction = WEST; temp_x-=1
                       else testedDirs |= WEST
                       end
               end

               # check next square to ensure it's valid
               if ( @matrix[temp_x][temp_y] != 0 ) 
                   # record direction as tested
                   testedDirs |= direction
                   # if all directions are invalid, impossible to
                   # select random direction so break out
                   if (testedDirs == ALL_DIRS) then break end
                   direction = 0
               end
           end
       else
           straightStretch+=1
       end

       # if all directions are tested, move on to next
       # iteration where an already-visited tile will be picked
       if (testedDirs == ALL_DIRS) then next end

       lastDir = direction

       # set selected direction in maze at both current tile
       # and destination tile
       @matrix[x][y] |= direction
       
       case direction
           when NORTH then y-=1; direction = SOUTH
           when EAST then x+=1; direction = WEST
           when SOUTH then y+=1; direction = NORTH
           when WEST then x-=1; direction = EAST
       end
       @matrix[x][y] |= direction
       testedDirs = @matrix[x][y]
       remaining-=1
   end
 end


=begin
   Sparsify the maze by the given amount ("sparsity") representing the
   number of times to sparsify (i.e. shorten deadends, creating empty areas so the
   maze isn't perfectly dense).

   A smaller maze will sparsify faster than a larger maze, so the smaller the maze,
   the smaller the number should be to accomplish the same relative amount of "sparsification".
=end
 def sparsify
   for i in 0...@sparsity
     for x in 0...@width
       for y in 0...@height
         # don't sparsify from the beginning or end points --
         # this guarantees a solution to the maze
         if (x == @startX) and (y == @startY) then next end

         if (x == @endX) and (y == @endY) then next end

         dir = @matrix[x][y]

         # if only one direction, found a deadend
         # so otherwise, go to next tile
         if not [NORTH, EAST, SOUTH, WEST].include?(dir)
           next
         end

         # remove deadend
         @matrix[x][y] = 0

         # for previous tile, remove direction to removed deadend
         # also temporarily flag it as visited so any new deadends
         # created aren't sparsified in the same pass
         case dir
           when NORTH
             @matrix[x][y-1] &= ~SOUTH
             @matrix[x][y-1] |= FLAG
           when EAST
             @matrix[x+1][y] &= ~WEST
             @matrix[x+1][y] |= FLAG
           when SOUTH
             @matrix[x][y+1] &= ~NORTH
             @matrix[x][y+1] |= FLAG
           when WEST
             @matrix[x-1][y] &= ~EAST
             @matrix[x-1][y] |= FLAG
         end

       end
     end

     # clear the flags for the next sparsifying pass
     for x in 0...@width
       for y in 0...@height
         @matrix[x][y] &= ~FLAG
       end
     end
   end

 end

=begin
   Display the matrix in an ASCII table (useful for debugging)
   (Much more readable if you're using a monospaced font for dialog boxes.)   
=end
 def display
   char_array = Array.new(@width, 0)
   for i in 0...@width
     char_array[i] = Array.new(@height, 0)
   end

   for x in 0...@width
     for y in 0...@height
       dir = @matrix[x][y]
       char = '['
       if ((dir & NORTH) != 0) then char << 'N' else char << ' ' end
       if ((dir & EAST) != 0) then char << 'E' else char << ' ' end
       if ((dir & WEST) != 0) then char << 'W' else char << ' ' end
       if ((dir & SOUTH) != 0) then char << 'S' else char << ' ' end
       char << ']'
       char_array[y][x] = char
     end
   end

   display = ''
   for i in 0...@height
     display << char_array[i].flatten.to_s << "\n"
   end
   print display
 end



=begin
   Clears the given percentage ("removalChance") of deadends from the maze by
   causing the deadends to extend until they hit another passage.  As this
   causes cycles in the maze, it can result in multiple possible solutions
   to the maze (but makes it seem more natural).
=end
   def removeDeadends

     for x in 0...@width
       for y in 0...@height

         dir = @matrix[x][y]

         # if only one direction, found a deadend
         # so otherwise, go to next tile
         if not [NORTH, EAST, SOUTH, WEST].include?(dir)
           next
         end

         # random roll to see if this deadend is skipped
         if (rand > @removalChance) then next end

         cur_x = x; cur_y = y
         back_dir = dir

         # continue as long as new corridor not reached
         while (@matrix[cur_x][cur_y] == back_dir)
           direction = 0
           testedDirs = 0

           # pick random direction
               # keep trying until a valid one is found
           while (direction == 0)
                 temp_x = cur_x
                 temp_y = cur_y

                 case rand(4)

                     when 0 # north
                         if (cur_y > 0) then direction = NORTH; back_dir = SOUTH; temp_y-=1
                         else testedDirs |= NORTH
                         end
                     when 1 # east
                         if (cur_x+1 < @width) then direction = EAST; back_dir = WEST; temp_x+=1
                         else testedDirs |= EAST
                         end
                     when 2 # south
                         if (cur_y+1 < @height) then direction = SOUTH; back_dir = NORTH; temp_y+=1
                         else testedDirs |= SOUTH
                         end
                     when 3 # west
                         if (cur_x > 0) then direction = WEST; back_dir = EAST; temp_x-=1
                         else testedDirs |= WEST
                         end
                 end

                 # check if deadend tile already goes this way
                 if ( @matrix[cur_x][cur_y] == direction )
                     # record direction as tested
                     testedDirs |= direction
                     direction = 0
                 end

                 # if all directions are invalid, impossible to
                 # select random direction so break out
                 if (testedDirs == ALL_DIRS) then break end
           end

           if (testedDirs == ALL_DIRS) then break end

           # add new direction to deadend
           @matrix[cur_x][cur_y] |= direction

           # add new direction to tile adjacent to deadend
           @matrix[temp_x][temp_y] |= back_dir

           # move on to next tile
           cur_x = temp_x; cur_y = temp_y

         end
     end
   end
 end    
    
end



module Tile

  @floor = 0
  @wallFace = 0
  @wall = 0
  # to be extended with others to make maps "pretty", e.g. random ground features

=begin
    The following array lists systematic keys which are based on adjacent
    walls (where 'W' is the wall itself):
    1 2 3
    4 W 6
    7 8 9
    e.g. 268 is the key that will be used to refer to the autotile
    which has adjacent walls north, east, and south.  For the Castle Prison
    tileset (autotile #1), this is 67.
    
    (It's a bit unwieldy, but it works.)
=end   
  
  Autotile_Keys = [
  12346789,
  2346789,
  1246789,
  246789,
  1234678,
  234678,
  124678,
  24678,
  
  1234689,
  234689,
  124689,
  24689,
  123468,
  23468,
  12468,
  2468,
  
  23689,
  2689,
  2368,
  268,
  46789,
  4678,
  4689,
  468,
  
  12478,
  1248,
  2478,
  248,
  12346, 
  2346,
  1246,
  246,
  
  28,
  46,
  689,
  68,
  478,
  48,
  124,
  24,
  
  236,
  26,
  8,
  6,
  2,
  4,
  0 ]
    
  # many autotiles handle multiple situations
  # this hash keeps track of which keys are identical
  # to ones already defined above
  Duplicate_Keys = {
  123689 => 23689,
  236789 => 23689,
  1236789 => 23689,
  34689 => 4689,
  14689 => 4689,
  134689 => 4689,
  14678 => 4678,
  34678 => 4678,
  134678 => 4678,
  146789 => 46789,
  346789 => 46789,
  1346789 => 46789,
  23467 => 2346,
  23469 => 2346,
  234679 => 2346,
  123467 => 12346,
  123469 => 12346,
  1234679 => 12346,
  12467 => 1246,
  12469 => 1246,
  124679 => 1246, 
  124789 => 12478,
  123478 => 12478,
  1234789 => 12478,
  146 => 46,
  346 => 46, 
  467 => 46, 
  469 => 46,
  1346 => 46, 
  1467 => 46,
  1469 => 46, 
  3467 => 46, 
  3469 => 46, 
  4679 => 46, 
  13467 => 46, 
  13469 => 46, 
  14679 => 46, 
  34679 => 46, 
  134679 => 46,
  128 => 28, 
  238 => 28, 
  278 => 28, 
  289 => 28, 
  1238 => 28, 
  1278 => 28,
  1289 => 28, 
  2378 => 28, 
  2389 => 28, 
  2789 => 28, 
  12378 => 28, 
  12389 => 28, 
  12789 => 28, 
  23789 => 28, 
  123789 => 28,
  
  1247 => 124,
  2369 => 236,
  147 => 4,
  247 => 24,
  14 => 4,
  47 => 4,
  1478 => 478,
  3478 => 478,
  4789 => 478,
  134789 => 478,
  14789 => 478,  
  13478 => 478,
  34789 => 478,
  1234 => 124,
  1247 => 124,
  1249 => 124,
  12347 => 124,
  12349 => 124,
  12479 => 124,
  123479 => 124,
  1236 => 236,
  2367 => 236,
  2369 => 236,
  12367 => 236,
  12369 => 236,
  23679 => 236,
  123679 => 236,
  12368 => 2368,
  23678 => 2368,  
  123678 => 2368,
  12348 => 1248,
  12489 => 1248,
  123489 => 1248,
  1689 => 689,
  3689 => 689,
  6789 => 689,
  13689 => 689,
  16789 => 689,
  36789 => 689,
  136789 => 689,
  12689 => 2689,
  26789 => 2689,  
  126789 => 2689,
  23478 => 2478,
  24789 => 2478,
  234789 => 2478
  }   
  
  def Tile.setFloor(row, col)
    if row > 1
      @floor = Tile.index(row, col)
    else # autotiles
      @floor = Hash.new(0)
      j = Tile.index(row, col)
      for i in Autotile_Keys
        @floor[i] = j
        j += 1
      end
      # add duplicates
      for i in Duplicate_Keys.keys
        @floor[i] = @floor[Duplicate_Keys[i]]
      end
    end
  end
    
  def Tile.floor
    @floor
  end    

  def Tile.setWallFace(row, col)
    if row > 1
      @wallFace = Tile.index(row, col)
    else # autotiles
      @wallFace = Hash.new(0)
      j = Tile.index(row, col)
      for i in Autotile_Keys
        @wallFace[i] = j
        j += 1
      end
      # add duplicates
      for i in Duplicate_Keys.keys
        @wallFace[i] = @wallFace[Duplicate_Keys[i]]
      end
    end
  end
    
  def Tile.wallFace
    @wallFace
  end
    
  def Tile.setWall(row, col)
    if row > 1
      @wall = Tile.index(row, col)
    else # autotiles
      @wall = Hash.new(0)
      j = Tile.index(row, col)
      for i in Autotile_Keys
        @wall[i] = j
        j += 1
      end
      # add duplicates
      for i in Duplicate_Keys.keys
        @wall[i] = @wall[Duplicate_Keys[i]]
      end
    end
  end

  def Tile.wall
    @wall
  end    

=begin
    This method returns the index of a specific tile in the tileset,
    or the base index for one of the 7 autotiles.
    Parameters:
        row  - row where the tile is found within the tileset ( 1+ )
        col - column where the tile is found within the tileset ( 1-8 )
    Note: this method is NOT zero-indexed, i.e. rows and columns start at 1
    
    e.g.
    index(1,2) returns 48
    index(2,1) returns 384
    index(4,8) returns 407 
    
    By the way, here's an example of how autotile indexes work...
    
        Autotile in column 2:
    
row\col| 1  2  3  4  5  6  7  8
     ---------------------------
     1 | 48 49 50 51 52 53 54 55
     2 | 56 57 58 59 60 61 62 63
     3 | 64 65 66 67 68 69 70 71
     4 | 72 73 74 75 76 77 78 79
     5 | 80 81 82 83 84 85 86 87
     6 | 88 89 90 91 92 93 94 95
     
     The function to return the index of a single tile within an autotile
     (given by at_index) is (at_index-1)*48 + col-1 + (row-1)*8
     (where row, col, and at_index are again NOT zero-indexed)
=end
  def Tile.index(row, col)
    if row > 1 # if not autotiles
      return 383 + col + 8*(row-2)
    else
      return (col-1)*48
    end
  end     

end
     
