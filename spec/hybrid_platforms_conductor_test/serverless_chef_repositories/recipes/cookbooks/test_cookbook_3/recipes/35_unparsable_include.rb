cookbook_name = ENV.fetch('cookbook_name', nil)
recipe_name = ENV.fetch('recipe_name', nil)
# rubocop:disable Style/StringConcatenation
include_recipe(
  cookbook_name + '::' + recipe_name
)
# rubocop:enable Style/StringConcatenation
