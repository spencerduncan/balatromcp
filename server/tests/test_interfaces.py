"""
Unit tests for interfaces module.
Tests that interfaces define proper contracts and are implemented correctly.
"""

import pytest
from abc import ABC, abstractmethod
from typing import get_type_hints
import inspect

from server.interfaces import (
    IFileIO,
    IStateManager,
    IActionHandler,
    IMCPServer,
    IGameSession,
)
from server.file_io import BalatroFileIO
from server.state_manager import BalatroStateManager
from server.action_handler import BalatroActionHandler
from server.main import BalatroMCPServer


class TestInterfaceDefinitions:
    """Test that interfaces are properly defined as abstract base classes."""
    
    def test_ifile_io_is_abstract(self):
        """Test that IFileIO is an abstract base class."""
        assert issubclass(IFileIO, ABC)
        
        # Should not be able to instantiate directly
        with pytest.raises(TypeError):
            IFileIO()
    
    def test_istate_manager_is_abstract(self):
        """Test that IStateManager is an abstract base class."""
        assert issubclass(IStateManager, ABC)
        
        with pytest.raises(TypeError):
            IStateManager()
    
    def test_iaction_handler_is_abstract(self):
        """Test that IActionHandler is an abstract base class."""
        assert issubclass(IActionHandler, ABC)
        
        with pytest.raises(TypeError):
            IActionHandler()
    
    def test_imcp_server_is_abstract(self):
        """Test that IMCPServer is an abstract base class."""
        assert issubclass(IMCPServer, ABC)
        
        with pytest.raises(TypeError):
            IMCPServer()
    
    def test_igame_session_is_abstract(self):
        """Test that IGameSession is an abstract base class."""
        assert issubclass(IGameSession, ABC)
        
        with pytest.raises(TypeError):
            IGameSession()


class TestIFileIOInterface:
    """Test IFileIO interface definition."""
    
    def test_interface_methods(self):
        """Test that IFileIO defines all required abstract methods."""
        abstract_methods = IFileIO.__abstractmethods__
        expected_methods = {
            'read_game_state',
            'write_action',
            'read_action_result',
            'get_next_sequence_id',
        }
        
        assert abstract_methods == expected_methods
    
    def test_method_signatures(self):
        """Test that IFileIO methods have correct signatures."""
        # Check read_game_state signature
        method = getattr(IFileIO, 'read_game_state')
        assert inspect.iscoroutinefunction(method)
        
        # Check write_action signature
        method = getattr(IFileIO, 'write_action')
        assert inspect.iscoroutinefunction(method)
        
        # Check read_action_result signature
        method = getattr(IFileIO, 'read_action_result')
        assert inspect.iscoroutinefunction(method)
        
        # Check get_next_sequence_id signature (not async)
        method = getattr(IFileIO, 'get_next_sequence_id')
        assert not inspect.iscoroutinefunction(method)


class TestIStateManagerInterface:
    """Test IStateManager interface definition."""
    
    def test_interface_methods(self):
        """Test that IStateManager defines all required abstract methods."""
        abstract_methods = IStateManager.__abstractmethods__
        expected_methods = {
            'get_current_state',
            'update_state',
            'is_state_changed',
        }
        
        assert abstract_methods == expected_methods
    
    def test_all_methods_async(self):
        """Test that all IStateManager methods are async."""
        methods = ['get_current_state', 'update_state', 'is_state_changed']
        
        for method_name in methods:
            method = getattr(IStateManager, method_name)
            assert inspect.iscoroutinefunction(method)


class TestIActionHandlerInterface:
    """Test IActionHandler interface definition."""
    
    def test_interface_methods(self):
        """Test that IActionHandler defines all required abstract methods."""
        abstract_methods = IActionHandler.__abstractmethods__
        expected_methods = {
            'execute_action',
            'validate_action',
            'get_available_actions',
        }
        
        assert abstract_methods == expected_methods
    
    def test_all_methods_async(self):
        """Test that all IActionHandler methods are async."""
        methods = ['execute_action', 'validate_action', 'get_available_actions']
        
        for method_name in methods:
            method = getattr(IActionHandler, method_name)
            assert inspect.iscoroutinefunction(method)


class TestIMCPServerInterface:
    """Test IMCPServer interface definition."""
    
    def test_interface_methods(self):
        """Test that IMCPServer defines all required abstract methods."""
        abstract_methods = IMCPServer.__abstractmethods__
        expected_methods = {
            'start',
            'stop',
            'handle_tool_call',
            'get_available_tools',
        }
        
        assert abstract_methods == expected_methods
    
    def test_all_methods_async(self):
        """Test that all IMCPServer methods are async."""
        methods = ['start', 'stop', 'handle_tool_call', 'get_available_tools']
        
        for method_name in methods:
            method = getattr(IMCPServer, method_name)
            assert inspect.iscoroutinefunction(method)


class TestIGameSessionInterface:
    """Test IGameSession interface definition."""
    
    def test_interface_methods(self):
        """Test that IGameSession defines all required abstract methods."""
        abstract_methods = IGameSession.__abstractmethods__
        expected_methods = {
            'initialize',
            'cleanup',
            'is_active',
            'get_session_id',
        }
        
        assert abstract_methods == expected_methods
    
    def test_all_methods_async(self):
        """Test that all IGameSession methods are async."""
        methods = ['initialize', 'cleanup', 'is_active', 'get_session_id']
        
        for method_name in methods:
            method = getattr(IGameSession, method_name)
            assert inspect.iscoroutinefunction(method)


class TestImplementationCompliance:
    """Test that concrete implementations properly implement interfaces."""
    
    def test_balatro_file_io_implements_interface(self):
        """Test that BalatroFileIO implements IFileIO correctly."""
        assert issubclass(BalatroFileIO, IFileIO)
        
        # Verify all abstract methods are implemented
        abstract_methods = IFileIO.__abstractmethods__
        for method_name in abstract_methods:
            assert hasattr(BalatroFileIO, method_name)
            method = getattr(BalatroFileIO, method_name)
            assert callable(method)
    
    def test_balatro_state_manager_implements_interface(self):
        """Test that BalatroStateManager implements IStateManager correctly."""
        assert issubclass(BalatroStateManager, IStateManager)
        
        # Verify all abstract methods are implemented
        abstract_methods = IStateManager.__abstractmethods__
        for method_name in abstract_methods:
            assert hasattr(BalatroStateManager, method_name)
            method = getattr(BalatroStateManager, method_name)
            assert callable(method)
    
    def test_balatro_action_handler_implements_interface(self):
        """Test that BalatroActionHandler implements IActionHandler correctly."""
        assert issubclass(BalatroActionHandler, IActionHandler)
        
        # Verify all abstract methods are implemented
        abstract_methods = IActionHandler.__abstractmethods__
        for method_name in abstract_methods:
            assert hasattr(BalatroActionHandler, method_name)
            method = getattr(BalatroActionHandler, method_name)
            assert callable(method)
    
    def test_balatro_mcp_server_implements_interface(self):
        """Test that BalatroMCPServer implements IMCPServer correctly."""
        assert issubclass(BalatroMCPServer, IMCPServer)
        
        # Verify all abstract methods are implemented
        abstract_methods = IMCPServer.__abstractmethods__
        for method_name in abstract_methods:
            assert hasattr(BalatroMCPServer, method_name)
            method = getattr(BalatroMCPServer, method_name)
            assert callable(method)


class TestInterfaceContractConsistency:
    """Test that interface contracts are consistent and logical."""
    
    def test_file_io_method_return_types(self):
        """Test that IFileIO method return types are properly annotated."""
        # This tests the type hints in the interface
        hints = get_type_hints(IFileIO.read_game_state)
        assert 'return' in hints
        
        hints = get_type_hints(IFileIO.write_action)
        assert 'return' in hints
        
        hints = get_type_hints(IFileIO.read_action_result)
        assert 'return' in hints
        
        hints = get_type_hints(IFileIO.get_next_sequence_id)
        assert 'return' in hints
    
    def test_state_manager_method_return_types(self):
        """Test that IStateManager method return types are properly annotated."""
        hints = get_type_hints(IStateManager.get_current_state)
        assert 'return' in hints
        
        hints = get_type_hints(IStateManager.update_state)
        assert 'return' in hints
        
        hints = get_type_hints(IStateManager.is_state_changed)
        assert 'return' in hints
    
    def test_action_handler_method_return_types(self):
        """Test that IActionHandler method return types are properly annotated."""
        hints = get_type_hints(IActionHandler.execute_action)
        assert 'return' in hints
        
        hints = get_type_hints(IActionHandler.validate_action)
        assert 'return' in hints
        
        hints = get_type_hints(IActionHandler.get_available_actions)
        assert 'return' in hints
    
    def test_mcp_server_method_return_types(self):
        """Test that IMCPServer method return types are properly annotated."""
        hints = get_type_hints(IMCPServer.start)
        assert 'return' in hints
        
        hints = get_type_hints(IMCPServer.stop)
        assert 'return' in hints
        
        hints = get_type_hints(IMCPServer.handle_tool_call)
        assert 'return' in hints
        
        hints = get_type_hints(IMCPServer.get_available_tools)
        assert 'return' in hints


class TestInterfaceDocumentation:
    """Test that interfaces have proper documentation."""
    
    def test_interface_docstrings(self):
        """Test that all interfaces have docstrings."""
        interfaces = [IFileIO, IStateManager, IActionHandler, IMCPServer, IGameSession]
        
        for interface in interfaces:
            assert interface.__doc__ is not None
            assert len(interface.__doc__.strip()) > 0
    
    def test_method_docstrings(self):
        """Test that interface methods have docstrings."""
        # Test IFileIO methods
        for method_name in IFileIO.__abstractmethods__:
            method = getattr(IFileIO, method_name)
            assert method.__doc__ is not None
            assert len(method.__doc__.strip()) > 0
        
        # Test IStateManager methods
        for method_name in IStateManager.__abstractmethods__:
            method = getattr(IStateManager, method_name)
            assert method.__doc__ is not None
            assert len(method.__doc__.strip()) > 0
        
        # Test IActionHandler methods
        for method_name in IActionHandler.__abstractmethods__:
            method = getattr(IActionHandler, method_name)
            assert method.__doc__ is not None
            assert len(method.__doc__.strip()) > 0


class TestDependencyInjectionSupport:
    """Test that interfaces support proper dependency injection."""
    
    def test_interfaces_can_be_mocked(self):
        """Test that interfaces can be properly mocked for testing."""
        from unittest.mock import Mock
        
        # Test that we can create mocks of interfaces
        mock_file_io = Mock(spec=IFileIO)
        mock_state_manager = Mock(spec=IStateManager) 
        mock_action_handler = Mock(spec=IActionHandler)
        mock_mcp_server = Mock(spec=IMCPServer)
        mock_game_session = Mock(spec=IGameSession)
        
        # Verify mocks have the expected methods
        assert hasattr(mock_file_io, 'read_game_state')
        assert hasattr(mock_state_manager, 'get_current_state')
        assert hasattr(mock_action_handler, 'execute_action')
        assert hasattr(mock_mcp_server, 'start')
        assert hasattr(mock_game_session, 'initialize')
    
    def test_constructor_dependency_injection(self):
        """Test that implementations accept interface dependencies."""
        from unittest.mock import Mock
        
        # Test BalatroStateManager accepts IFileIO
        mock_file_io = Mock(spec=IFileIO)
        state_manager = BalatroStateManager(mock_file_io)
        assert state_manager.file_io == mock_file_io
        
        # Test BalatroActionHandler accepts dependencies
        mock_state_manager = Mock(spec=IStateManager)
        action_handler = BalatroActionHandler(mock_file_io, mock_state_manager)
        assert action_handler.file_io == mock_file_io
        assert action_handler.state_manager == mock_state_manager


class TestInterfaceSegregation:
    """Test that interfaces follow the Interface Segregation Principle."""
    
    def test_interfaces_are_focused(self):
        """Test that each interface has a single, focused responsibility."""
        # IFileIO should only handle file operations
        file_io_methods = IFileIO.__abstractmethods__
        assert all('read' in method or 'write' in method or 'sequence' in method 
                  for method in file_io_methods)
        
        # IStateManager should only handle state management
        state_methods = IStateManager.__abstractmethods__
        assert all('state' in method or 'changed' in method 
                  for method in state_methods)
        
        # IActionHandler should only handle actions
        action_methods = IActionHandler.__abstractmethods__
        assert all('action' in method for method in action_methods)
    
    def test_no_interface_overlap(self):
        """Test that interfaces don't have overlapping responsibilities."""
        # Get all method names from all interfaces
        all_methods = set()
        interfaces = [IFileIO, IStateManager, IActionHandler, IMCPServer, IGameSession]
        
        for interface in interfaces:
            interface_methods = getattr(interface, '__abstractmethods__', set())
            # Check for overlapping method names (which might indicate overlapping responsibilities)
            overlap = all_methods.intersection(interface_methods)
            assert len(overlap) == 0, f"Found overlapping methods: {overlap}"
            all_methods.update(interface_methods)