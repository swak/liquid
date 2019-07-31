require 'test_helper'

class PartialCacheUnitTest < Minitest::Test
  def test_uses_the_file_system_register_if_present
    context = Liquid::Context.build(
      registers: {
        file_system: StubFileSystem.new('my_partial' => 'my partial body')
      }
    )
    cache = Liquid::PartialCache.for(
      context,
      parse_context: Liquid::ParseContext.new
    )

    partial = cache.load('my_partial')

    assert_equal 'my partial body', partial.render
  end

  def test_reads_from_the_file_system_only_once_per_file
    file_system = StubFileSystem.new('my_partial' => 'some partial body')
    context = Liquid::Context.build(
      registers: { file_system: file_system }
    )
    cache = Liquid::PartialCache.for(
      context,
      parse_context: Liquid::ParseContext.new
    )

    cache.load('my_partial')
    cache.load('my_partial')

    assert_equal 1, file_system.file_read_count
  end

  def test_cache_state_is_stored_per_context
    parse_context = Liquid::ParseContext.new
    shared_file_system = StubFileSystem.new(
      'my_partial' => 'my shared value'
    )
    context_one = Liquid::Context.build(
      registers: {
        file_system: shared_file_system
      }
    )
    context_two = Liquid::Context.build(
      registers: {
        file_system: shared_file_system
      }
    )
    shared_cache_one = Liquid::PartialCache.new(
      context_one,
      parse_context: parse_context
    )
    shared_cache_two = Liquid::PartialCache.new(
      context_one,
      parse_context: parse_context
    )
    lone_cache = Liquid::PartialCache.new(
      context_two,
      parse_context: parse_context
    )

    shared_read_one = shared_cache_one.load('my_partial')
    shared_read_two = shared_cache_two.load('my_partial')
    lone_read = lone_cache.load('my_partial')

    assert_equal 'my shared value', shared_read_one.render
    assert_equal 'my shared value', shared_read_two.render
    assert_equal 'my shared value', lone_read.render

    assert_equal 2, shared_file_system.file_read_count
  end

  def test_cache_is_not_broken_when_a_different_parse_context_is_used
    file_system = StubFileSystem.new('my_partial' => 'some partial body')
    shared_parse_context = Liquid::ParseContext.new(my_key: 'value one')
    context = Liquid::Context.build(
      registers: { file_system: file_system }
    )
    cache_one = Liquid::PartialCache.for(
      context,
      parse_context: shared_parse_context
    )
    cache_two = Liquid::PartialCache.for(
      context,
      parse_context: shared_parse_context
    )

    cache_one.load('my_partial')
    cache_two.load('my_partial')

    # Technically what we care about is that the file was parsed twice,
    # but measureing file reads is an OK proxy for this.
    assert_equal 1, file_system.file_read_count
  end
end
