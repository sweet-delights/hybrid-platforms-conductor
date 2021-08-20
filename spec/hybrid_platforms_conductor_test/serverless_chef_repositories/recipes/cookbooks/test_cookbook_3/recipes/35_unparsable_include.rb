cookbook_name = ENV['cookbook_name']
recipe_name = ENV['recipe_name']
# rubocop:disable Style/StringConcatenation
include_recipe(
  cookbook_name + '::' + recipe_name
)
# rubocop:enable Style/StringConcatenation
