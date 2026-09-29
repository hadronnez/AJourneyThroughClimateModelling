using Logging

export init_logger, close_logger

# Custom logger that flushes after each message
struct FlushingLogger <: AbstractLogger
    stream::IO
    min_level::LogLevel
end

Logging.shouldlog(logger::FlushingLogger, level, _module, group, id) = level >= logger.min_level

Logging.min_enabled_level(logger::FlushingLogger) = logger.min_level

function Logging.handle_message(logger::FlushingLogger, level, msg, _module, group, id, file, line; kwargs...)
    println(logger.stream, msg)
    flush(logger.stream)
end

"""
    init_logger(log_path::String)

Initialize the global logger with FlushingLogger pointing to log_path.
Returns the IO handle.
"""
function init_logger(log_path::String)
    mkpath(dirname(log_path))
    io = open(log_path, "a")
    global_logger(FlushingLogger(io, Logging.Info))
    return io
end

"""
    close_logger(io::IO)

Close the logger IO handle.
"""
function close_logger(io::IO)
    close(io)
end