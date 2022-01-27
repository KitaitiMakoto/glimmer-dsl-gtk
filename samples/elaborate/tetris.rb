require 'glimmer-dsl-gtk'

require_relative 'tetris/model/game'

class Tetris
  include Glimmer
  
  BLOCK_SIZE = 25
  BEVEL_CONSTANT = 20
  COLOR_GRAY = [192, 192, 192]
    
  def initialize
    @game = Model::Game.new
  end
  
  def launch
    create_gui
    register_observers
    @game.start!
    @main_window.show
  end
  
  def create_gui
    @main_window = window {
      title 'Glimmer Tetris'
      default_size Model::Game::PLAYFIELD_WIDTH * BLOCK_SIZE, Model::Game::PLAYFIELD_HEIGHT * BLOCK_SIZE # + 98
      
      box(:vertical) {
        @playfield_blocks = playfield(playfield_width: @game.playfield_width, playfield_height: @game.playfield_height, block_size: BLOCK_SIZE)
      }
      
      on(:key_press_event) do |widget, key_event|
        case key_event.keyval
        when 65364 # down arrow
          @game.down!
        when 32 # space
          @game.down!(instant: true)
        when 65362 # up arrow
          case @game.up_arrow_action
          when :instant_down
            @game.down!(instant: true)
          when :rotate_right
            @game.rotate!(:right)
          when :rotate_left
            @game.rotate!(:left)
          end
        when 65361 # left arrow
          @game.left!
        when 65363 # right arrow
          @game.right!
        when 65506 # right shift
          @game.rotate!(:right)
        when 65505 # left shift
          @game.rotate!(:left)
        else
          # Do Nothing
        end
      end
    }
  end
  
  def register_observers
    observe(@game, :game_over) do |game_over|
      if game_over
        show_game_over_dialog
      else
        start_moving_tetrominos_down
      end
    end
    
    @game.playfield_height.times do |row|
      @game.playfield_width.times do |column|
        observe(@game.playfield[row][column], :color) do |new_color|
          color = new_color
          block = @playfield_blocks[row][column]
          block[:background_square].fill = color
          block[:top_bevel_edge].fill = [color[0] + 4*BEVEL_CONSTANT, color[1] + 4*BEVEL_CONSTANT, color[2] + 4*BEVEL_CONSTANT]
          block[:right_bevel_edge].fill = [color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT]
          block[:bottom_bevel_edge].fill = [color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT]
          block[:left_bevel_edge].fill = [color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT]
          block[:border_square].stroke = new_color == Model::Block::COLOR_CLEAR ? COLOR_GRAY : color
          block[:drawing_area].queue_draw
          false
        end
      end
    end
  end
  
  def playfield(playfield_width: , playfield_height: , block_size: , &extra_content)
    blocks = []
    box(:vertical) {
      playfield_height.times.map do |row|
        blocks << []
        box(:horizontal) {
          playfield_width.times.map do |column|
            blocks.last << block(row: row, column: column, block_size: block_size)
          end
        }
      end
      
      extra_content&.call
    }
    blocks
  end
  
  def block(row: , column: , block_size: , &extra_content)
    block = {}
    bevel_pixel_size = 0.16 * block_size.to_f
    color = Model::Block::COLOR_CLEAR
    block[:drawing_area] = drawing_area {
      size_request block_size, block_size
      
      block[:background_square] = square(0, 0, block_size) {
        fill *color
      }
      
      block[:top_bevel_edge] = polygon(0, 0, block_size, 0, block_size - bevel_pixel_size, bevel_pixel_size, bevel_pixel_size, bevel_pixel_size) {
        fill color[0] + 4*BEVEL_CONSTANT, color[1] + 4*BEVEL_CONSTANT, color[2] + 4*BEVEL_CONSTANT
      }
       
      block[:right_bevel_edge] = polygon(block_size, 0, block_size - bevel_pixel_size, bevel_pixel_size, block_size - bevel_pixel_size, block_size - bevel_pixel_size, block_size, block_size) {
        fill color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT
      }
       
      block[:bottom_bevel_edge] = polygon(block_size, block_size, 0, block_size, bevel_pixel_size, block_size - bevel_pixel_size, block_size - bevel_pixel_size, block_size - bevel_pixel_size) {
        fill color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT
      }
      
      block[:left_bevel_edge] = polygon(0, 0, 0, block_size, bevel_pixel_size, block_size - bevel_pixel_size, bevel_pixel_size, bevel_pixel_size) {
        fill color[0] - BEVEL_CONSTANT, color[1] - BEVEL_CONSTANT, color[2] - BEVEL_CONSTANT
      }
      
      block[:border_square] = square(0, 0, block_size) {
        stroke *COLOR_GRAY
      }
      
      extra_content&.call
    }
    block
  end
  
  def start_moving_tetrominos_down
    unless @tetrominos_start_moving_down
      @tetrominos_start_moving_down = true
      GLib::Timeout.add(@game.delay*1000) do
        @game.down! if !@game.game_over? && !@game.paused?
        true
      end
    end
  end
  
  def show_game_over_dialog
    message_dialog(@main_window) { |md|
      title 'Game Over!'
      text "Score: #{@game.high_scores.first.score}\nLines: #{@game.high_scores.first.lines}\nLevel: #{@game.high_scores.first.level}"
      
      on(:response) do
        md.destroy
      end
    }.show
    
    @game.restart!
    false
  end
end

Tetris.new.launch