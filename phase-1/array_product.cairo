%builtins output

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.serialize import serialize_word

func array_product(arr : felt*, size) -> (prod):
    if size == 0:
        return (prod=1)  # we return 1 as base case because anything * 0 is 0 and thus we will not return the correct result
    end
    let (prod_of_rest) = array_product(arr=arr + 1, size=size - 1)
    return (prod=[arr] * prod_of_rest)
end

func main{output_ptr : felt*}():
    const ARR_SIZE = 3
    let (ptr) = alloc()

    assert [ptr] = 9  # assigns first memory cell in array to 9
    assert [ptr + 1] = 16
    assert [ptr + 2] = 25

    let (product) = array_product(arr=ptr, size=ARR_SIZE)

    serialize_word(product)
    return ()
end
