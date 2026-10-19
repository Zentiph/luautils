--!strict

-- core types
-- by @vuppyan

-- functions
export type Action = () -> ()
export type Predicate<T> = (value: T) -> boolean
export type Supplier<T> = () -> T
export type Consumer<T> = (value: T) -> ()
export type Mapper<T, U> = (value: T) -> U
export type Iterator<T> = () -> T?

-- types/traits
export type Iterable<T> = { T }

return nil
