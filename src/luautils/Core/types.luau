--!strict

-- core types
-- by @vuppyan

export type Action = () -> ()
export type Predicate<T> = (value: T) -> boolean
export type Supplier<T> = () -> T
export type Consumer<T> = (value: T) -> ()
export type Mapper<T, U> = (value: T) -> U
export type Zipper<T, U, R> = (a: T, b: U) -> R

return nil
