require 'command_line_reporter'
require 'tty-cursor'
require 'pry'
require 'pry-byebug'

class GUI
  include CommandLineReporter

  attr_reader :data, :cursor

  MAPPING = {:bids => 'green', :asks => 'red'}

  def initialize(data)
    @data = data
  end

  def self.clear_screen
    print TTY::Cursor.clear_screen
  end

  def display_table
    [:asks, :bids].each do |type|
      header title: type.to_s.capitalize, align: 'center', width: 40
      table(border: true) do
       row :color => MAPPING[type] do
         column('PRICE', width: 20)
         column('QUANTITY', width: 20)
       end

       data[type].each do |quote|
         row do
           column(quote[0])
           column(quote[1].round(2))
         end
       end
     end
   end
  end
end
