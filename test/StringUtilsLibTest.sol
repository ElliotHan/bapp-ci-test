pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "../contracts/StringUtilsLib.sol";

contract StringUtilsLibTest {
	using StringUtilsLib for *;

	string stringA;
	string stringB;
    string[] stringArray;

	event Print(string message, bytes32 data);

    function testRfind() public {
        stringA = "I will be";
        stringB = "will";
        Assert.equal(stringA.rfind(stringB), "I will", "testRfind");
    }

    function testLen() public {
        stringA = "I love Klaytn!!";
        stringB = "나는 야근이 너무 좋아";
        Assert.equal(stringA.len(), 15, "Should return the right length");
        Assert.equal(stringB.len(), 12, "Should return the right length");
    }

    function testEmpty() public {
        stringA = "";
        stringB = "not empty";
        Assert.isTrue(stringA.empty(), "Must be true when empty");
        Assert.isFalse(stringB.empty(), "Must be false when not empty");
    }

    function testCompare() public {
        stringA = "abc";
        stringB = "bcd";
        Assert.isTrue(stringA.compare(stringB) < 0, "Must return negative number when A lexicographically comes before than B");
        stringA = "bcd";
        stringB = "abc";
        Assert.isTrue(stringA.compare(stringB) > 0, "Must return positive number when A lexicographically comes before than B");
        stringA = "cc";
        stringB = "cc";
        Assert.equal(stringB.compare(stringA), 0, "Must return zero when A and B are the same");
    }

    function testOrd() public {
        stringA = "a";
        stringB = "0";
        Assert.equal(stringA.ord(), 97, "Must return the right ascii code");
        Assert.equal(stringB.ord(), 48, "Must return the right ascii code");
    }

    function testStartsWith() public {
        stringA = "So~, sally can't wait";
        stringB = "So~";
        Assert.isTrue(stringA.startsWith(stringB), "Must return true when A starts with B");
        stringA = "She knows it's too late";
        stringB = "too";
        Assert.isFalse(stringA.startsWith(stringB), "Must return false when A does not start with B");
    }

    function testBeyond() public {
        stringA = "So~, sally can't wait";
        stringB = "So~";
        Assert.equal(stringA.beyond(stringB), ", sally can't wait", "Must return string A excluding string B if A starts with B");
        stringA = "She knows it's too late";
        stringB = "too";
        Assert.equal(stringA.beyond(stringB), "She knows it's too late", "Nothing happens when A does not start with B");
    }

    function testEndsWith() public {
        stringA = "So~, sally can't wait";
        stringB = "wait";
        Assert.isTrue(stringA.endsWith(stringB), "Must return true when A ends with B");
        stringA = "She knows it's too late";
        stringB = "too";
        Assert.isFalse(stringA.endsWith(stringB), "Must return false when A does not end with B");
    }

    function testUntil() public {
        stringA = "So~, sally can't wait";
        stringB = "wait";
        Assert.equal(stringA.until(stringB), "So~, sally can't ", "Must return string A excluding string B if A ends with B");
        stringA = "She knows it's too late";
        stringB = "too";
        Assert.equal(stringA.beyond(stringB), "She knows it's too late", "Nothing happens when A does not end with B");
    }

    function testFind() public {
        stringA = "Smells like teen spirit";
        stringB = "teen";
        Assert.equal(stringA.find(stringB), "teen spirit", "Must return everything from the first occurence of string B in string A");
        stringA = "Smells like teen spirit";
        stringB = "twenty";
        Assert.equal(stringA.find(stringB), "", "Must return empty string if string B is not found");
    }

    function testSplit() public {
        stringA = "Smells like teen spirit";
        stringArray = stringA.split(" ");
        Assert.equal(stringArray[0], "Smells", "Must split using string B and return string array");
        Assert.equal(stringArray[1], "like", "Must split using string B and return string array");
        Assert.equal(stringArray[2], "teen", "Must split using string B and return string array");
        Assert.equal(stringArray[3], "spirit", "Must split using string B and return string array");
    }

    function testCount() public {
        stringA = "how many a's are there in a aland";
        stringB = "a";
        Assert.equal(stringA.count(stringB), 6, "Must count the number of string B in string A");
    }

    function testContains() public {
        stringA = "세계로 뻗어 나가는 클레이튼";
        stringB = "클레이튼";
        Assert.isTrue(stringA.contains(stringB), "Must return true if string A contains string B");
        Assert.isFalse(stringA.contains("random"), "Must return false if string A does not contain string B");
    }

    function testJoin() public {
        stringArray[0] = "You";
        stringArray[1] = "are";
        stringArray[2] = "my";
        stringArray[3] = "everything";
        Assert.equal(" ".join(stringArray), "You are my everything", "Must return joined string");
        Assert.equal(stringArray.join(" "), "You are my everything", "Must return joined string");
    }

    function testPadStart() public {
        stringA = "123123";
        Assert.equal(stringA.padStart(10, "x"), "xxxx123123", "Must return string of target size padded to the left");
    }

    function testPadEnd() public {
        stringA = "123123";
        Assert.equal(stringA.padEnd(10, "0"), "1231230000", "Must return string of target size padded to the right");
    }
    
    function testSubstring() public {
        stringA = "Mozilla";
        Assert.equal(stringA.substring(0, 6), "Mozill", "Must return the right substring");
        Assert.equal(stringA.substring(7, 4), "lla", "Must return the right substring");
        Assert.equal(stringA.substring(0, 10), "Mozilla", "Must return the right substring");
    }
}


