pragma solidity ^0.5.0;

/*
 * @title String & slice memory utility library for Solidity contracts.
 * @author Nick Johnson <arachnid@notdot.net>
 *
 * version 1.2.0
 * Copyright 2016 Nick Johnson
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * This utility library was forked from https://github.com/Arachnid/solidity-stringutils
 * into the Modular ethereum-libraries repo at https://github.com/Modular-Network/ethereum-libraries
 * with permission. It has been updated to be more compatible with solidity 0.4.18
 * coding patterns.
 *
 * Modular provides smart contract services and security reviews for contract
 * deployments in addition to working on open source projects in the Ethereum
 * community. Our purpose is to test, document, and deploy reusable code onto the
 * blockchain and improve both security and usability. We also educate non-profits,
 * schools, and other community members about the application of blockchain
 * technology. For further information: modular.network
 *
 * @dev Functionality in this library is largely implemented using an
 *      abstraction called a 'slice memory'. A slice memory represents a part of a string -
 *      anything from the entire string to a single character, or even no
 *      characters at all (a 0-length slice memory). Since a slice memory only has to specify
 *      an offset and a length, copying and manipulating slice memorys is a lot less
 *      expensive than copying and manipulating the strings they reference.
 *
 *      To further reduce gas costs, most functions on slice memory that need to return
 *      a slice memory modify the original one instead of allocating a new one; for
 *      instance, `s.split(".")` will return the text up to the first '.',
 *      modifying s to only contain the remainder of the string after the '.'.
 *      In situations where you do not want to modify the original slice memory, you
 *      can make a copy first with `.copy()`, for example:
 *      `s.copy().split(".")`. Try and avoid using this idiom in loops; since
 *      Solidity has no memory management, it will result in allocating many
 *      short-lived slice memorys that are later discarded.
 *
 *      Functions that return two slice memorys come in two versions: a non-allocating
 *      version that takes the second slice memory as an argument, modifying it in
 *      place, and an allocating version that allocates and returns the second
 *      slice memory; see `nextRune` for example.
 *
 *      Functions that have to copy string data will return strings rather than
 *      slice memorys; these can be cast back to slice memorys for further processing if
 *      required.
 *
 *      For convenience, some functions are provided with non-modifying
 *      variants that create a new slice memory and return both; for instance,
 *      `s.splitNew('.')` leaves s unmodified, and returns two values
 *      corresponding to the left and right parts of the string.
 */

library StringUtilsLib {
    struct slice {
        uint _len;
        uint _ptr;
    }

    function memcpy(uint dest, uint src, uint len) private pure {
        // Copy word-length chunks while possible
        for(; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice memory containing the entire string.
     * @param self The string to make a slice memory from.
     * @return A newly allocated slice memory containing the entire string.
     */
    function toSlice (string memory self) internal returns (slice memory) {
        uint ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns the length of a null-terminated bytes32 string.
     * @param self The value to find the length of.
     * @return The length of the string, from 0 to 32.
     */
    function len(bytes32 self) internal returns (uint) {
        uint ret;
        if (self == 0)
            return 0;
        if (self & bytes32(uint(0xffffffffffffffffffffffffffffffff)) == 0) {
            ret += 16;
            self = bytes32(uint(self) / 0x100000000000000000000000000000000);
        }
        if (self & bytes32(uint(0xffffffffffffffff)) == 0) {
            ret += 8;
            self = bytes32(uint(self) / 0x10000000000000000);
        }
        if (self & bytes32(uint(0xffffffff)) == 0) {
            ret += 4;
            self = bytes32(uint(self) / 0x100000000);
        }
        if (self & bytes32(uint(0xffff)) == 0) {
            ret += 2;
            self = bytes32(uint(self) / 0x10000);
        }
        if (self & bytes32(uint(0xff)) == 0) {
            ret += 1;
        }
        return 32 - ret;
    }

    /*
     * @dev Returns a slice memory containing the entire bytes32, interpreted as a
     *      null-termintaed utf-8 string.
     * @param self The bytes32 value to convert to a slice memory.
     * @return A new slice memory containing the value of the input argument up to the
     *         first null.
     */
    function tosliceB32(bytes32 self) internal returns (slice memory ret) {
        // Allocate space for `self` in memory, copy it there, and point ret at it
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            mstore(ptr, self)
            mstore(add(ret, 0x20), ptr)
        }
        ret._len = len(self);
    }

    /*
     * @dev Returns a new slice memory containing the same data as the current slice memory.
     * @param self The slice memory to copy.
     * @return A new slice memory containing the same data as `self`.
     */
    function copy(slice memory self) internal returns (slice memory) {
        return slice(self._len, self._ptr);
    }

    /*
     * @dev Copies a slice memory to a new string.
     * @param self The slice memory to copy.
     * @return A newly allocated string containing the slice memory's text.
     */
    function toString(slice memory self) internal view returns (string memory) {
        string memory ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    /*
     * @dev Returns the length in runes of the slice memory. Note that this operation
     *      takes time proportional to the length of the slice memory; avoid using it
     *      in loops, and call `slice memory.empty()` if you only need to know whether
     *      the slice memory is empty or not.
     * @param self The slice memory to operate on.
     * @return The length of the slice memory in runes.
     */
    function len(slice memory self) internal view returns (uint) {
        // Starting at ptr-31 means the LSB will be the byte we care about
        uint ptr = self._ptr - 31;
        uint end = ptr + self._len;
        uint len;
        for (len = 0; ptr < end; len++) {
            uint8 b;
            assembly {
                b := and(mload(ptr), 0xFF)
            }
            if (b < 0x80) {
                ptr += 1;
            } else if(b < 0xE0) {
                ptr += 2;
            } else if(b < 0xF0) {
                ptr += 3;
            } else if(b < 0xF8) {
                ptr += 4;
            } else if(b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
        return len;
    }


    //Takes string and returns uint
    function len(string memory self) internal returns (uint) {
        return len(toSlice(self));
    }

    /*
     * @dev Returns true if the slice memory is empty (has a length of 0).
     * @param self The slice memory to operate on.
     * @return True if the slice memory is empty, False otherwise.
     */
    function empty(slice memory self) internal view returns (bool) {
        return self._len == 0;
    }
    
    //Takes string and returns bool
    function empty(string memory self) internal returns (bool) {
        return empty(toSlice(self));
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two slice memorys are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first slice memory to compare.
     * @param other The second slice memory to compare.
     * @return The result of the comparison.
     */
    function compare(slice memory self, slice memory other) internal view returns (int) {
        uint shortest = self._len;
        if (other._len < self._len)
            shortest = other._len;

        uint selfptr = self._ptr;
        uint otherptr = other._ptr;
        for (uint idx = 0; idx < shortest; idx += 32) {
            uint a;
            uint b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                uint diff = (a & mask) - (b & mask);
                if (diff != 0)
                    return int(diff);
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int(self._len) - int(other._len);
    }

    //Takes string and returns int
    function compare(string memory self, string memory other) internal returns (int) {
        return compare(toSlice(self), toSlice(other));
    }

    /*
     * @dev Returns true if the two slice memorys contain the same text.
     * @param self The first slice memory to compare.
     * @param self The second slice memory to compare.
     * @return True if the slice memorys are equal, false otherwise.
     */
    function equals(slice memory self, slice memory other) internal view returns (bool) {
        return compare(self, other) == 0;
    }

    //Takes string and returns bool
    function equals(string memory self, string memory other) internal returns (bool) {
        return compare(toSlice(self), toSlice(other)) == 0;
    }

    /*
     * @dev Extracts the first rune in the slice memory into `rune`, advancing the
     *      slice memory to point to the next rune and returning `rune`.
     * @param self The slice memory to operate on.
     * @param rune The slice memory that will contain the first rune.
     * @return `rune`.
     */
    function nextRune(slice memory self, slice memory rune) internal returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint len;
        uint b;
        // Load the first byte of the rune into the LSBs of b
        assembly { b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF) }
        if (b < 0x80) {
            len = 1;
        } else if(b < 0xE0) {
            len = 2;
        } else if(b < 0xF0) {
            len = 3;
        } else {
            len = 4;
        }

        // Check for truncated codepoints
        if (len > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += len;
        self._len -= len;
        rune._len = len;
        return rune;
    }

    /*
     * @dev Returns the first rune in the slice memory, advancing the slice memory to point
     *      to the next rune.
     * @param self The slice memory to operate on.
     * @return A slice memory containing only the first rune from `self`.
     */
    function nextRune(slice memory self) internal returns (slice memory ret) {
        nextRune(self, ret);
    }

    /*
     * @dev Returns the number of the first codepoint in the slice memory.
     * @param self The slice memory to operate on.
     * @return The number of the first codepoint in the slice memory.
     */
    function ord(slice memory self) internal view returns (uint ret) {
        if (self._len == 0) {
            return 0;
        }

        uint word;
        uint len;
        uint div = 2 ** 248;

        // Load the rune into the MSBs of b
        assembly { word:= mload(mload(add(self, 32))) }
        uint b = word / div;
        if (b < 0x80) {
            ret = b;
            len = 1;
        } else if(b < 0xE0) {
            ret = b & 0x1F;
            len = 2;
        } else if(b < 0xF0) {
            ret = b & 0x0F;
            len = 3;
        } else {
            ret = b & 0x07;
            len = 4;
        }

        // Check for truncated codepoints
        if (len > self._len) {
            return 0;
        }

        for (uint i = 1; i < len; i++) {
            div = div / 256;
            b = (word / div) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }
    
    //Takes string and returns uint
    function ord(string memory self) internal returns (uint ret) {
        return ord(toSlice(self));
    }


    /*
     * @dev Returns the keccak-256 hash of the slice memory.
     * @param self The slice memory to hash.
     * @return The hash of the slice memory.
     */
    function keccak(slice memory self) internal view returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /*
     * @dev Returns true if `self` starts with `needle`.
     * @param self The slice memory to operate on.
     * @param needle The slice memory to search for.
     * @return True if the slice memory starts with the provided text, false otherwise.
     */
    function startsWith(slice memory self, slice memory needle) internal view returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        if (self._ptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let len := mload(needle)
            let selfptr := mload(add(self, 0x20))
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, len), keccak256(needleptr, len))
        }
        return equal;
    }
    
    //Takes string and returns bool
    function startsWith(string memory self, string memory needle) internal returns (bool) {
        return startsWith(toSlice(self), toSlice(needle));
    }

    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice memory to operate on.
     * @param needle The slice memory to search for.
     * @return `self`
     */
    function beyond(slice memory self, slice memory needle) internal returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let len := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, len), keccak256(needleptr, len))
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }

    //Takes string and returns string
    function beyond(string memory self, string memory needle) internal returns (string memory) {
        return(toString(beyond(toSlice(self), toSlice(needle))));
    }

    /*
     * @dev Returns true if the slice memory ends with `needle`.
     * @param self The slice memory to operate on.
     * @param needle The slice memory to search for.
     * @return True if the slice memory starts with the provided text, false otherwise.
     */
    function endsWith(slice memory self, slice memory needle) internal view returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        uint selfptr = self._ptr + self._len - needle._len;

        if (selfptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let len := mload(needle)
            let needleptr := mload(add(needle, 0x20))
            equal := eq(keccak256(selfptr, len), keccak256(needleptr, len))
        }

        return equal;
    }

    //Takes string and returns bool
    function endsWith(string memory self, string memory needle) internal returns (bool) {
        return endsWith(toSlice(self), toSlice(needle));
    }

    /*
     * @dev If `self` ends with `needle`, `needle` is removed from the
     *      end of `self`. Otherwise, `self` is unmodified.
     * @param self The slice memory to operate on.
     * @param needle The slice memory to search for.
     * @return `self`
     */
    function until(slice memory self, slice memory needle) internal returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        uint selfptr = self._ptr + self._len - needle._len;
        bool equal = true;
        if (selfptr != needle._ptr) {
            assembly {
                let len := mload(needle)
                let needleptr := mload(add(needle, 0x20))
                equal := eq(keccak256(selfptr, len), keccak256(needleptr, len))
            }
        }

        if (equal) {
            self._len -= needle._len;
        }

        return self;
    }
    
    //Takes string and return string
    function until(string memory self, string memory needle) internal returns (string memory) {
        return(toString(until(toSlice(self), toSlice(needle))));
    }


    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function findPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr)
      private
      view
      returns (uint)
    {
        uint ptr;
        uint idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                // Optimized assembly for 68 gas per byte on short strings
                assembly {
                    let mask := not(sub(exp(2, mul(8, sub(32, needlelen))), 1))
                    let needledata := and(mload(needleptr), mask)
                    let end := add(selfptr, sub(selflen, needlelen))
                    let loop := selfptr

                    for { } lt(loop, end) { } {
                        switch eq(and(mload(loop), mask), needledata)
                        case 1 {
                            ptr := loop
                            loop := end
                        }
                        case 0 {
                            loop := add(loop,1)
                        }
                    }
                    switch eq(and(mload(ptr), mask), needledata)
                    case 0 {
                        ptr := add(selfptr, selflen)
                    }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                ptr = selfptr;
                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr;
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    // Returns the memory address of the first byte after the last occurrence of
    // `needle` in `self`, or the address of `self` if not found.
    function rfindPtr(uint selflen, uint selfptr, uint needlelen, uint needleptr)
      private
      view
      returns (uint)
    {
        uint ptr;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                // Optimized assembly for 69 gas per byte on short strings
                assembly {
                    let mask := not(sub(exp(2, mul(8, sub(32, needlelen))), 1))
                    let needledata := and(mload(needleptr), mask)
                    let loop := add(selfptr, sub(selflen, needlelen))

                    for { } gt(loop, selfptr) { } {
                        switch eq(and(mload(loop), mask), needledata)
                        case 1 {
                            ptr := loop
                            loop := selfptr
                        }
                        case 0 {
                            loop := sub(loop,1)
                        }
                    }
                    switch eq(and(mload(ptr), mask), needledata)
                    case 1 {
                        ptr := add(ptr, needlelen)
                    }
                    case 0 {
                        ptr := selfptr
                    }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly { hash := keccak256(needleptr, needlelen) }
                ptr = selfptr + (selflen - needlelen);
                while (ptr >= selfptr) {
                    bytes32 testHash;
                    assembly { testHash := keccak256(ptr, needlelen) }
                    if (hash == testHash)
                        return ptr + needlelen;
                    ptr -= 1;
                }
            }
        }
        return selfptr;
    }

    /*
     * @dev Modifies `self` to contain everything from the first occurrence of
     *      `needle` to the end of the slice memory. `self` is set to the empty slice memory
     *      if `needle` is not found.
     * @param self The slice memory to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function find(slice memory self, slice memory needle) internal returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len -= ptr - self._ptr;
        self._ptr = ptr;
        return self;
    }

    //Takes string and returns string
    function find(string memory self, string memory needle) internal returns (string memory) {
        return (toString(find(toSlice(self), toSlice(needle))));
    }

    /*
     * @dev Modifies `self` to contain the part of the string from the start of
     *      `self` to the end of the first occurrence of `needle`. If `needle`
     *      is not found, `self` is set to the empty slice memory.
     * @param self The slice memory to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function rfind(slice memory self, slice memory needle) internal returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len = ptr - self._ptr;
        return self;
    }

    //Takes string and returns string
    function rfind(string memory self, string memory needle) internal returns (string memory) {
        return (toString(rfind(toSlice(self), toSlice(needle))));
    }

    /*
     * @dev Splits the slice memory, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice memory,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice memory to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function split(slice memory self, slice memory needle, slice memory token) internal returns (slice memory) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice memory, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice memory,
     *      and the entirety of `self` is returned.
     * @param self The slice memory to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(slice memory self, slice memory needle) internal returns (slice memory token) {
        split(self, needle, token);
    }
    
    //Takes string and returns string array
    function split(string memory self, string memory needle) internal returns (string[] memory) {
        string[] memory parts = new string[](count(toSlice(self), toSlice(needle))+1);
        slice memory self = toSlice(self);
        for(uint i = 0; i < parts.length; i++) {
            parts[i] = toString(split(self, toSlice(needle)));
        }
        return parts;
    }


    /*
     * @dev Splits the slice memory, setting `self` to everything before the last
     *      occurrence of `needle`, and `token` to everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice memory,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice memory to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function rsplit(slice memory self, slice memory needle, slice memory token) internal returns (slice memory) {
        uint ptr = rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = ptr;
        token._len = self._len - (ptr - self._ptr);
        if (ptr == self._ptr) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice memory, setting `self` to everything before the last
     *      occurrence of `needle`, and returning everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice memory,
     *      and the entirety of `self` is returned.
     * @param self The slice memory to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` after the last occurrence of `delim`.
     */
    function rsplit(slice memory self, slice memory needle) internal returns (slice memory token) {
        rsplit(self, needle, token);
    }

    /*
     * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
     * @param self The slice memory to search.
     * @param needle The text to search for in `self`.
     * @return The number of occurrences of `needle` found in `self`.
     */
    function count(slice memory self, slice memory needle) internal view returns (uint count) {
        uint ptr = findPtr(self._len, self._ptr, needle._len, needle._ptr) + needle._len;
        while (ptr <= self._ptr + self._len) {
            count++;
            ptr = findPtr(self._len - (ptr - self._ptr), ptr, needle._len, needle._ptr) + needle._len;
        }
    }
    
    //Takes string and returns uint
    function count(string memory self, string memory needle) internal returns (uint) {
        return count(toSlice(self), toSlice(needle));
    }

    /*
     * @dev Returns True if `self` contains `needle`.
     * @param self The slice memory to search.
     * @param needle The text to search for in `self`.
     * @return True if `needle` is found in `self`, false otherwise.
     */
    function contains(slice memory self, slice memory needle) internal view returns (bool) {
        return rfindPtr(self._len, self._ptr, needle._len, needle._ptr) != self._ptr;
    }
    
    //Takes string
    function contains(string memory self, string memory needle) internal returns (bool) {
        return contains(toSlice(self), toSlice(needle));
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of
     *      `self` and `other`.
     * @param self The first slice memory to concatenate.
     * @param other The second slice memory to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(slice memory self, slice memory other) internal view returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slice memorys, using `self` as a delimiter, returning a
     *      newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slice memorys to join.
     * @return A newly allocated string containing all the slice memorys in `parts`,
     *         joined with `self`.
     */
    function join(slice memory self, slice[] memory parts) internal view returns (string memory) {
        if (parts.length == 0)
            return "";

        uint i;
        uint len = self._len * (parts.length - 1);
        for(i = 0; i < parts.length; i++)
            len += parts[i]._len;

        string memory ret = new string(len);
        uint retptr;
        assembly { retptr := add(ret, 32) }

        for(i = 0; i < parts.length; i++) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }

        return ret;
    }
    
    //Takes string returns string
    function join(string memory self, string[] memory parts) internal returns (string memory) {
        uint length = parts.length;
        slice[] memory slices = new slice[](length);
        for(uint i = 0; i < length; i++) {
            slices[i] = toSlice(parts[i]);
        }
        return join(toSlice(self), slices);
    }
    
    //Javascript style join
    function join(string[] memory parts, string memory self) internal returns (string memory) {
        uint length = parts.length;
        slice[] memory slices = new slice[](length);
        for(uint i = 0; i < length; i++) {
            slices[i] = toSlice(parts[i]);
        }
        return join(toSlice(self), slices);
    }

    //Pad chars from the left until it reaches the targetLength (including self)
    function padStart(slice memory self, uint targetLength, slice memory pad) internal returns (string memory) {
        if(self._len >= targetLength) {
            return toString(self);
        }
        string memory ret = new string(targetLength);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        uint i;
        for(i = 0; i < targetLength; i = i + pad._len) {
            memcpy(retptr+i, pad._ptr, pad._len);
        }
        memcpy(retptr + targetLength - self._len, self._ptr, self._len);
        return ret;
    }
    
    function padStart(string memory self, uint targetLength, string memory pad) internal returns (string memory) {
        return padStart(toSlice(self), targetLength, toSlice(pad));
    }

    //Pad chars from right until it reaches the targetLength (including self)
    function padEnd(slice memory self, uint targetLength, slice memory pad) internal returns (string memory) {
        if(self._len >= targetLength) {
            return toString(self);
        }
        string memory ret = new string(targetLength);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr, self._len);
        uint i;
        for(i = 0; i < targetLength - self._len; i = i + pad._len) {
            memcpy(retptr+self._len + i, pad._ptr, pad._len);
        }
        return ret;
    }
    
    function padEnd(string memory self, uint targetLength, string memory pad) internal returns (string memory) {
        return padEnd(toSlice(self), targetLength, toSlice(pad));
    }

    //Takes string and returns a part
    function substring(slice memory self, uint beginIndex, uint endIndex) internal returns (string memory) {
        if(endIndex > self._len - 1) endIndex = self._len;
        if(beginIndex > endIndex) {
            uint temp = beginIndex;
            beginIndex = endIndex;
            endIndex = temp;
        }
        if(beginIndex == endIndex) return new string(0);
        string memory ret = new string(endIndex-beginIndex);
        uint retptr;
        assembly { retptr := add(ret, 32) }
        memcpy(retptr, self._ptr + beginIndex, endIndex-beginIndex);
        return ret;
    }
    
    function substring(string memory self, uint beginIndex, uint endIndex) internal returns (string memory) {
        return substring(toSlice(self), beginIndex, endIndex);    
    }
    
}
