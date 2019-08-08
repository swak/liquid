require 'test_helper'

class RenderTagTest < Minitest::Test
  include Liquid

  def test_render_with_no_arguments
    Liquid::Template.file_system = StubFileSystem.new('source' => 'rendered content')
    assert_template_result 'rendered content', '{% render "source" %}'
  end

  def test_render_tag_looks_for_file_system_in_registers_first
    file_system = StubFileSystem.new('pick_a_source' => 'from register file system')
    assert_equal 'from register file system',
      Template.parse('{% render "pick_a_source" %}').render!({}, registers: { file_system: file_system })
  end

  def test_render_passes_named_arguments_into_inner_scope
    Liquid::Template.file_system = StubFileSystem.new('product' => '{{ inner_product.title }}')
    assert_template_result 'My Product', '{% render "product", inner_product: outer_product %}',
      'outer_product' => { 'title' => 'My Product' }
  end

  def test_render_accepts_literals_as_arguments
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ price }}')
    assert_template_result '123', '{% render "snippet", price: 123 %}'
  end

  def test_render_accepts_multiple_named_arguments
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ one }} {{ two }}')
    assert_template_result '1 2', '{% render "snippet", one: 1, two: 2 %}'
  end

  def test_render_does_not_inherit_parent_scope_variables
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ outer_variable }}')
    assert_template_result '', '{% assign outer_variable = "should not be visible" %}{% render "snippet" %}'
  end

  def test_render_does_not_inherit_variable_with_same_name_as_snippet
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ snippet }}')
    assert_template_result '', "{% assign snippet = 'should not be visible' %}{% render 'snippet' %}"
  end

  def test_render_sets_the_correct_template_name_for_errors
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ unsafe }}')

    with_taint_mode :error do
      template = Liquid::Template.parse('{% render "snippet", unsafe: unsafe %}')
      context = Context.new('unsafe' => String.new('unsafe').tap(&:taint))
      template.render(context)

      assert_equal [Liquid::TaintedError], template.errors.map(&:class)
      assert_equal 'snippet', template.errors.first.template_name
    end
  end

  def test_render_sets_the_correct_template_name_for_warnings
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{{ unsafe }}')

    with_taint_mode :warn do
      template = Liquid::Template.parse('{% render "snippet", unsafe: unsafe %}')
      context = Context.new('unsafe' => String.new('unsafe').tap(&:taint))
      template.render(context)

      assert_equal [Liquid::TaintedError], context.warnings.map(&:class)
      assert_equal 'snippet', context.warnings.first.template_name
    end
  end

  def test_render_does_not_mutate_parent_scope
    Liquid::Template.file_system = StubFileSystem.new('snippet' => '{% assign inner = 1 %}')
    assert_template_result '', "{% render 'snippet' %}{{ inner }}"
  end

  def test_nested_render_tag
    Liquid::Template.file_system = StubFileSystem.new(
      'one' => "one {% render 'two' %}",
      'two' => 'two'
    )
    assert_template_result 'one two', "{% render 'one' %}"
  end

  def test_recursively_rendered_template_does_not_produce_endless_loop
    Liquid::Template.file_system = StubFileSystem.new('loop' => '{% render "loop" %}')

    assert_raises Liquid::StackLevelError do
      Template.parse('{% render "loop" %}').render!
    end
  end

  def test_includes_and_renders_count_towards_the_same_recursion_limit
    Liquid::Template.file_system = StubFileSystem.new(
      'loop_render' => '{% render "loop_include" %}',
      'loop_include' => '{% include "loop_render" %}'
    )

    assert_raises Liquid::StackLevelError  do
      Template.parse('{% render "loop_include" %}').render!
    end
  end

  def test_dynamically_choosen_templates_are_not_allowed
    Liquid::Template.file_system = StubFileSystem.new('snippet' => 'should not be rendered')

    assert_raises Liquid::SyntaxError do
      Liquid::Template.parse("{% assign name = 'snippet' %}{% render name %}")
    end
  end

  def test_include_tag_caches_second_read_of_same_partial
    file_system = StubFileSystem.new('snippet' => 'echo')
    assert_equal 'echoecho',
      Template.parse('{% render "snippet" %}{% render "snippet" %}')
              .render!({}, registers: { file_system: file_system })
    assert_equal 1, file_system.file_read_count
  end

  def test_render_tag_doesnt_cache_partials_across_renders
    file_system = StubFileSystem.new('snippet' => 'my message')

    assert_equal 'my message',
      Template.parse('{% include "snippet" %}').render!({}, registers: { file_system: file_system })
    assert_equal 1, file_system.file_read_count

    assert_equal 'my message',
      Template.parse('{% include "snippet" %}').render!({}, registers: { file_system: file_system })
    assert_equal 2, file_system.file_read_count
  end

  def test_render_tag_within_if_statement
    Liquid::Template.file_system = StubFileSystem.new('snippet' => 'my message')
    assert_template_result 'my message', '{% if true %}{% render "snippet" %}{% endif %}'
  end

  def test_break_through_render
    Liquid::Template.file_system = StubFileSystem.new('break' => '{% break %}')
    assert_template_result '1', '{% for i in (1..3) %}{{ i }}{% break %}{{ i }}{% endfor %}'
    assert_template_result '112233', '{% for i in (1..3) %}{{ i }}{% render "break" %}{{ i }}{% endfor %}'
  end

  def test_increment_is_isolated_between_renders
    skip 'Increment currently leaks between tests'

    Liquid::Template.file_system = StubFileSystem.new('incr' => '{% increment %}')
    assert_template_result '010', '{% increment %}{% increment %}{% render "incr" %}'
  end
end
