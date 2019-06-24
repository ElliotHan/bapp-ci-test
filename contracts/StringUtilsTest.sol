import './StringUtilsLib.sol';

contract StringUtilsTest {
    using StringUtilsLib for *;
    
    
    function length(string memory s) public returns(uint) {
        return s.toSlice().len();
    }
    
    function split() public returns(string memory) {
        StringUtilsLib.slice memory s = "foo bar baz".toSlice();
        StringUtilsLib.slice memory foo = s.split(" ".toSlice());
        return foo.toString();
    }
    
    
    function split2() public returns(string memory) {
        StringUtilsLib.slice memory s = "foo bar baz".toSlice();
        StringUtilsLib.slice memory foo = s.split(" ".toSlice());
        return s.toString();
    }
    
    function concat() public returns(string memory) {
        string memory s = "abc".toSlice().concat("def".toSlice()); // "abcdef"
        return s;
    }
    
    function find() public returns(string memory) {
        StringUtilsLib.slice memory s = "A B C B D".toSlice();
        StringUtilsLib.slice memory needle = "B".toSlice();
        StringUtilsLib.slice memory substring =  s.until(s.copy().find(needle).beyond(needle));
        return substring.toString();
    }
    
    function join() public returns(string memory) {
        StringUtilsLib.slice[] memory a;
        a[0] = "abc".toSlice();
        a[1] = "bdc".toSlice();
        string memory s = "be m B";
        string memory c = s.toSlice().join(a);
        
        return c;
    }
    
    function testcode() public returns (string memory) {
        
    }

}